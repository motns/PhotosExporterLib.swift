/*
Copyright (C) 2025 Adam Borocz

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/
import Foundation
import Photos
import Logging

protocol PhotokitProtocol {
  func getAllAssetsResult() async throws -> any AssetFetchResultProtocol

  func getAssetIdsForAlbumId(albumId: String) throws -> [String]

  func getRootFolder() throws -> PhotokitFolder

  func getSharedAlbums() throws -> [PhotokitAlbum]

  func copyResource(
    assetId: String,
    resourceType: PhotokitAssetResourceType,
    originalFileName: String,
    destination: URL,
  ) async throws -> ResourceCopyResult
}

/*
Library for abstracting away calls to the Photokit framework
*/
// swiftlint:disable:next type_body_length
struct Photokit: PhotokitProtocol {
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
      throw PhotokitError.authotisationError(
        "Access to Photos has been denied to exporter - please grant full permission"
      )
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

  func fetchResultToArray<T>(_ res: PHFetchResult<T>) -> [T] {
    var ls: [T] = []
    res.enumerateObjects { object, _, _ in
      ls.append(object)
    }
    return ls
  }

  func getAllAssetsResult() async throws -> any AssetFetchResultProtocol {
    let allAssetsFetch = PHFetchOptions()
    allAssetsFetch.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
    // allAssetsFetch.fetchLimit = 25

    var fetchResults = [PhotokitFetchResult<PHAsset, PhotokitAsset>]()

    fetchResults.append(PhotokitFetchResult(PHAsset.fetchAssets(with: allAssetsFetch)) { asset in
      if let photokitAsset = try await self.getPhotokitAssetForPHAsset(
        asset: asset,
        library: .personalLibrary
      ) {
        return .success(photokitAsset)
      } else {
        return .skip
      }
    })

    for sharedAlbum in fetchResultToArray(PHAssetCollection.fetchAssetCollections(
      with: .album,
      subtype: .albumCloudShared,
      options: nil
    )) {
      fetchResults.append(PhotokitFetchResult(
        PHAsset.fetchAssets(in: sharedAlbum, options: allAssetsFetch)
      ) { asset in
        if let photokitAsset = try await self.getPhotokitAssetForPHAsset(
          asset: asset,
          library: .sharedAlbum
        ) {
          return .success(photokitAsset)
        } else {
          return .skip
        }
      })
    }

    return AssetFetchResultBatch(fetchResults)
  }

  private func getPhotokitAssetForPHAsset(asset: PHAsset, library: AssetLibrary) async throws -> PhotokitAsset? {
    let assetId = asset.localIdentifier

    guard [.audio, .image, .video].contains(asset.mediaType) else {
      self.logger.debug(
        "Unsupported Media Type for Asset",
        [
          "asset_id": "\(assetId)",
          "media_type": "\(asset.mediaType)",
        ]
      )
      return nil
    }

    var resources = [PhotokitAssetResource]()
    for resource in PHAssetResource.assetResources(for: asset) {
      self.logger.trace("Converting PHAssetResource to PhotokitAssetResource...", [
        "asset_id": "\(assetId)",
        "type": "\(resource.type)",
        "original_file_name": "\(resource.originalFilename)",
      ])
      let fileSize = try await self.getResourceSize(resource: resource)
      resources.append(PhotokitAssetResource.fromPHAssetResource(resource: resource, fileSize: fileSize))
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
        collectionSubtype: .albumCloudShared,
        assetIds: try self.getAssetIdsForAlbumId(albumId: assetCollection.localIdentifier)
      )
    }
  }

  func getRootFolder() throws -> PhotokitFolder {
    return try getFolder(folderId: Photokit.RootFolderId)
  }

  private func getFolder(folderId: String) throws -> PhotokitFolder {
    let folderOpt: PHCollectionList?

    if folderId == Photokit.RootFolderId {
      folderOpt = nil
    } else {
      let collectionWithIdOpt = fetchResultToArray(PHCollectionList.fetchCollectionLists(
        withLocalIdentifiers: [folderId], options: nil
      )).first

      guard let collectionWithId = collectionWithIdOpt else {
        throw PhotokitError.invalidCollectionListId(folderId)
      }

      folderOpt = collectionWithId
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
            folderId: subfolder.localIdentifier
          ))
        }
      } else if let album = collection as? PHAssetCollection {
        if let title = album.localizedTitle, FileHelper.normaliseForPath(title) != "" {
          albums.append(PhotokitAlbum(
            id: album.localIdentifier,
            title: title,
            collectionSubtype: .albumRegular,
            assetIds: try self.getAssetIdsForAlbumId(albumId: album.localIdentifier),
          ))
        }
      }
    }

    return PhotokitFolder(
      id: folderId,
      title: folderOpt?.localizedTitle ?? "Untitled",
      subfolders: subfolders,
      albums: albums,
    )
  }

  private func getResourceSize(resource: PHAssetResource) async throws -> Int64 {
    let loggerMetadata: Logger.Metadata = [
      "asset_id": "\(resource.assetLocalIdentifier)",
      "file_type": "\(resource.type)",
      "original_file_name": "\(resource.originalFilename)",
    ]
    logger.trace("Getting size for Asset Resource...", loggerMetadata)

    // This is an undocumented attribute, so the behaviour is mainly speculation,
    // but it's been suggested that it may be set to 0 if the Resource hasn't yet been
    // downloaded from iCloud to the local device
    if let fileSize = resource.value(forKey: "fileSize") as? Int64, fileSize != 0 {
      return fileSize
    } else {
      logger.warning(
        "fileSize attribute missing or zero for Asset Resource - reading it from file contents...",
        loggerMetadata
      )
      var fileSize: Int64 = 0
      return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int64, Error>) in
        PHAssetResourceManager.default().requestData(
          for: resource,
          options: nil,
        ) { data in
          fileSize += Int64(data.count)
        } completionHandler: { error in
          if let error {
            continuation.resume(throwing: error)
          } else {
            continuation.resume(returning: fileSize)
          }
        }
      }
    }
  }

  func copyResource(
    assetId: String,
    resourceType: PhotokitAssetResourceType,
    originalFileName: String,
    destination: URL,
  ) async throws -> ResourceCopyResult {
    let assetOpt = fetchResultToArray(PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)).first
    guard let asset = assetOpt else {
      return ResourceCopyResult.removed
    }

    let assetResourceType = resourceType.toPHAssetResourceType()
    var resourceOpt: PHAssetResource?
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
