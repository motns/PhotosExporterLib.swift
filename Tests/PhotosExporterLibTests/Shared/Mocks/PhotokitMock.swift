import Foundation
@testable import PhotosExporterLib

class PhotokitMock: PhotokitProtocol {
  var assets: [PhotokitAsset]
  var albums: [PhotokitAlbum]
  var sharedAlbums: [PhotokitAlbum]
  var rootAlbums: [PhotokitAlbum]
  var rootFolders: [PhotokitFolder]

  public private(set) var copyResourceCalls: [CopyResourceCall]
  var copyResourceResponse: ResourceCopyResult

  init() {
    self.assets = []
    self.albums = []
    self.sharedAlbums = []
    self.rootAlbums = []
    self.rootFolders = []
    self.copyResourceCalls = []
    self.copyResourceResponse = .copied
  }

  func resetCalls() {
    copyResourceCalls = []
  }

  func getAllAssetsResult() throws -> any AssetFetchResultProtocol {
    return AssetFetchResultMock(assets)
  }

  func getAssetIdsForAlbumId(albumId: String) throws -> [String] {
    let indexOpt = albums.firstIndex { album in
      album.id == albumId
    }

    guard let index = indexOpt else {
      throw PhotokitError.invalidAlbumId(albumId)
    }

    return albums[index].assetIds
  }

  func getRootFolder() throws -> PhotokitFolder {
    return PhotokitFolder(
      id: Photokit.RootFolderId,
      title: "Untitled",
      subfolders: self.rootFolders,
      albums: self.rootAlbums,
    )
  }

  func getSharedAlbums() -> [PhotokitAlbum] {
    return sharedAlbums
  }

  func copyResource(
    assetId: String,
    resourceType: PhotokitAssetResourceType,
    originalFileName: String,
    destination: URL,
  ) async throws -> ResourceCopyResult {
    copyResourceCalls.append(CopyResourceCall(
      assetId: assetId,
      resourceType: resourceType,
      originalFileName: originalFileName,
      destination: destination
    ))
    return copyResourceResponse
  }
}

struct CopyResourceCall: Hashable {
  let assetId: String
  let resourceType: PhotokitAssetResourceType
  let originalFileName: String
  let destination: URL
}
