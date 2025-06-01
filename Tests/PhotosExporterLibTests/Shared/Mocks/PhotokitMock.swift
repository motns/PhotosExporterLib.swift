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

struct CopyResourceCall: Diffable, DiffableStruct {
  let assetId: String
  let resourceType: PhotokitAssetResourceType
  let originalFileName: String
  let destination: URL

  func getDiffAsString(_ other: CopyResourceCall) -> String? {
    var out = ""
    out += propertyDiff("assetId", self.assetId, other.assetId) ?? ""
    out += propertyDiff("resourceType", self.resourceType, other.resourceType) ?? ""
    out += propertyDiff("originalFileName", self.originalFileName, other.originalFileName) ?? ""
    out += propertyDiff("destination", self.destination, other.destination) ?? ""
    return out != "" ? out : nil
  }
}
