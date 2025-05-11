import Foundation
import Photos
import Logging

protocol PhotokitProtocol: Actor {
  func getAllAssets() async -> [PhotokitAsset]

  func getAssetIdsForAlbumId(albumId: String) throws -> [String]

  func getRootFolder() throws -> PhotokitFolder

  func getFolder(folderId: String, parentIdOpt: String?) throws -> PhotokitFolder

  func getSharedAlbums() throws -> [PhotokitAlbum]

  func copyResource(
    assetId: String,
    fileType: FileType,
    originalFileName: String,
    destination: URL,
  ) async throws -> ResourceCopyResult
}

/*
Library for abstracting away calls to the Photokit framework
*/
actor Photokit: PhotokitProtocol {
  private let logger: ClassLogger

  static let RootFolderId = "ROOT"

  init(logger: Logger) async throws {
    self.logger = ClassLogger(
      logger: logger,
      className: "Photokit",
    )

    do {
      try await authorisePhotos()
    } catch {
      logger.critical("Failed to initialise PhotokitLib")
      throw error
    }
  }

  private func authorisePhotos() async throws {
    logger.debug("Checking access to Photos...")

    switch PHPhotoLibrary.authorizationStatus(for: PHAccessLevel.readWrite) {
    case .authorized:
      logger.debug("Already authorised :)")
    case .limited:
      throw PhotokitError.authotisationError("App only has limited access - please grant full permission")
    case .restricted:
      throw PhotokitError.authotisationError("You do not have permissions to give access to the Photos library")
    case .denied:
      throw PhotokitError.authotisationError("Access to Photos has been denied to exporter - please grant full permission")
    case .notDetermined:
      // We haven't asked for access before
      switch await PHPhotoLibrary.requestAuthorization(for: PHAccessLevel.readWrite) {
        case .authorized:
          logger.debug("Received authorisation :D")
          return
        case .limited, .restricted, .denied, .notDetermined:
          throw PhotokitError.authotisationError("You must grant full permission to the exporter")
        @unknown default:
          throw PhotokitError.unexpectedError("Received unrecognised authorisation status")
      }
    @unknown default:
      throw PhotokitError.unexpectedError("Current authorisation status not recognised")
    }
  }

  func getAllAssets() -> [PhotokitAsset] {
    let allAssetsFetch = PHFetchOptions()
    allAssetsFetch.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
    //allAssetsFetch.fetchLimit = 25

    var mainLibraryAssets = [PhotokitAsset]()
    PHAsset.fetchAssets(with: allAssetsFetch).enumerateObjects { asset, _, _ in
      if let photokitAsset = self.getPhotokitAssetForPHAsset(asset: asset, library: .personalLibrary) {
        mainLibraryAssets.append(photokitAsset)
      }
    }

    var sharedAlbumAssets = [PhotokitAsset]()

    PHAssetCollection.fetchAssetCollections(
      with: .album,
      subtype: .albumCloudShared,
      options: nil
    ).enumerateObjects { sharedAlbum, _, _ in
      PHAsset.fetchAssets(in: sharedAlbum, options: allAssetsFetch).enumerateObjects { asset, _, _ in
        if let photokitAsset = self.getPhotokitAssetForPHAsset(asset: asset, library: .sharedAlbum) {
          sharedAlbumAssets.append(photokitAsset)
        }
      }
    }

    return mainLibraryAssets + sharedAlbumAssets
  }

  private func getPhotokitAssetForPHAsset(asset: PHAsset, library: AssetLibrary) -> PhotokitAsset? {
    let assetId = asset.localIdentifier

    guard [.audio, .image, .video].contains(asset.mediaType) else {
      self.logger.debug(
        "Unsupported Media Type for Asset",
        [
          "asset_id": "\(assetId)",
          "media_type": "\(asset.mediaType)"
        ]
      )
      return nil
    }

    let resources = PHAssetResource.assetResources(for: asset).map { resource in
      self.logger.trace("Converting PHAssetResource to PhotokitAssetResource...", [
        "asset_id": "\(assetId)",
        "type": "\(resource.type)",
        "original_file_name": "\(resource.originalFilename)",
      ])
      return PhotokitAssetResource.fromPHAssetResource(resource: resource)
    }
    self.logger.trace("Converting PHAsset to PhotokitAsset...", [
      "asset_id": "\(assetId)"
    ])

    return PhotokitAsset.fromPHAsset(asset: asset, library: library, resources: resources)
  }

  func getAssetIdsForAlbumId(albumId: String) throws -> [String] {
    let albumOpt = fetchResultToArray(PHAssetCollection.fetchAssetCollections(
      withLocalIdentifiers: [albumId],
      options: nil
    )).first

    guard let album = albumOpt else {
      throw PhotokitError.invalidAlbumId(albumId)
    }

    var assetIds = [String]()
    let fetchOpt = PHFetchOptions()
    fetchOpt.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

    PHAsset.fetchAssets(in: album, options: fetchOpt).enumerateObjects { asset, _, _ in
      assetIds.append(asset.localIdentifier)
    }

    return assetIds
  }

  func getSharedAlbums() throws -> [PhotokitAlbum] {
    let fetchOpt = PHFetchOptions()
    fetchOpt.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]

    return try fetchResultToArray(PHAssetCollection.fetchAssetCollections(
      with: .album,
      subtype: .albumCloudShared,
      options: fetchOpt
    )).compactMap { assetCollection in
      guard let title = assetCollection.localizedTitle else {
        return nil
      }

      return PhotokitAlbum(
        id: assetCollection.localIdentifier,
        title: title,
        folderId: Photokit.RootFolderId,
        collectionSubtype: .albumCloudShared,
        assetIds: try self.getAssetIdsForAlbumId(albumId: assetCollection.localIdentifier)
      )
    }
  }

  func getRootFolder() throws -> PhotokitFolder {
    return try getFolder(folderId: Photokit.RootFolderId, parentIdOpt: nil)
  }

  func getFolder(folderId: String, parentIdOpt: String? = nil) throws -> PhotokitFolder {
    let folderOpt: PHCollectionList?
    let parentId: String?
    
    if folderId == Photokit.RootFolderId {
      folderOpt = nil
      parentId = nil
    } else {
      let collectionWithIdOpt = fetchResultToArray(PHCollectionList.fetchCollectionLists(
        withLocalIdentifiers: [folderId], options: nil
      )).first

      guard let collectionWithId = collectionWithIdOpt else {
        throw PhotokitError.invalidCollectionListId(folderId)
      }

      guard let pId = parentIdOpt else {
        throw PhotokitError.missingParentId
      }
      
      folderOpt = collectionWithId
      parentId = pId
    }

    var subfolders = [PhotokitFolder]()
    var albums = [PhotokitAlbum]()

    let fetchOpt = PHFetchOptions()
    fetchOpt.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]
    let res: PHFetchResult<PHCollection> = if let folder = folderOpt {
      // This returns Albums and Folders inside a Folder (CollectionList)
      PHCollection.fetchCollections(in: folder, options: fetchOpt)
    } else {
      // This returns Albums (AssetCollection) and Folders (CollectionList) at the root of the library
      PHCollection.fetchTopLevelUserCollections(with: fetchOpt)
    }

    for collection in fetchResultToArray(res) {
      // PHCollection is a superclass of both CollectionList and AssetCollection, so we
      // need to check the type of each element to determine which subtype it is, and treat
      // it as a Folder or Album accordingly
      if let subfolder = collection as? PHCollectionList {
        if let title = subfolder.localizedTitle, FileHelper.normaliseForPath(title) != "" {
          subfolders.append(try self.getFolder(
            folderId: subfolder.localIdentifier,
            parentIdOpt: folderId
          ))
        }
      } else if let album = collection as? PHAssetCollection {
        if let title = album.localizedTitle, FileHelper.normaliseForPath(title) != "" {
          albums.append(PhotokitAlbum(
            id: album.localIdentifier,
            title: title,
            folderId: folderId,
            collectionSubtype: .albumRegular,
            assetIds: try self.getAssetIdsForAlbumId(albumId: album.localIdentifier),
          ))
        }
      }
    }

    return PhotokitFolder(
      id: folderId,
      title: folderOpt?.localizedTitle ?? "Untitled",
      parentId: parentId,
      subfolders: subfolders,
      albums: albums,
    )
  }

  func copyResource(
    assetId: String,
    fileType: FileType,
    originalFileName: String,
    destination: URL,
  ) async throws -> ResourceCopyResult {
    let assetOpt = fetchResultToArray(PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)).first
    guard let asset = assetOpt else {
      return ResourceCopyResult.removed
    }

    let assetResourceType = PhotokitAssetResourceType.fromExporterFileType(
      fileType: fileType
    ).toPHAssetResourceType()
    var resourceOpt: PHAssetResource? = nil
    for resource in PHAssetResource.assetResources(for: asset) {
      if resource.type == assetResourceType && resource.originalFilename == originalFileName {
        resourceOpt = resource
        break
      }
    }

    guard let resource = resourceOpt else {
      return ResourceCopyResult.removed
    }

    guard !FileManager.default.fileExists(atPath: destination.path(percentEncoded: false)) else {
      return ResourceCopyResult.exists
    }

    try await PHAssetResourceManager.default().writeData(for: resource, toFile: destination, options: nil)
    return ResourceCopyResult.copied
  }

  func fetchResultToArray<T>(_ res: PHFetchResult<T>) -> [T] {
    var ls: [T] = []
    res.enumerateObjects { o, _, _ in
      ls.append(o)
    }
    return ls
  }
}

enum PhotokitError: Error {
  case authotisationError(String)
  case invalidCollectionListId(String)
  case missingParentId
  case invalidAlbumId(String)
  case unsupportedAlbumType(Int)
  case unexpectedError(String)
}

enum ResourceCopyResult: Sendable {
  case copied, exists, removed
}
