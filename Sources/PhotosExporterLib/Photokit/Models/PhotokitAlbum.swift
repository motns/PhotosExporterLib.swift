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

enum PhotokitAssetCollectionSubType: Int, Sendable {
  case albumRegular = 2
  case albumSyncedEvent = 3
  case albumSyncedFaces = 4
  case albumSyncedAlbum = 5
  case albumImported = 6
  case albumMyPhotoStream = 100
  case albumCloudShared = 101
  case smartAlbumGeneric = 200
  case smartAlbumPanoramas = 201
  case smartAlbumVideos = 202
  case smartAlbumFavorites = 203
  case smartAlbumTimelapses = 204
  case smartAlbumAllHidden = 205
  case smartAlbumRecentlyAdded = 206
  case smartAlbumBursts = 207
  case smartAlbumSlomoVideos = 208
  case smartAlbumUserLibrary = 209
  case smartAlbumSelfPortraits = 210
  case smartAlbumScreenshots = 211
  case smartAlbumDepthEffect = 212
  case smartAlbumLivePhotos = 213
  case smartAlbumAnimated = 214
  case smartAlbumLongExposures = 215
  case smartAlbumUnableToUpload = 216
  case smartAlbumRAW = 217
  case smartAlbumCinematic = 218
  case smartAlbumSpatial = 219
  case any = 9223372036854775807
}

struct PhotokitAlbum: Sendable {
  let id: String
  let title: String
  let collectionSubtype: PhotokitAssetCollectionSubType
  let assetIds: [String]

  func copy(
    id: String? = nil,
    title: String? = nil,
    collectionSubtype: PhotokitAssetCollectionSubType? = nil,
    assetIds: [String]? = nil,
  ) -> PhotokitAlbum {
    return PhotokitAlbum(
      id: id ?? self.id,
      title: title ?? self.title,
      collectionSubtype: collectionSubtype ?? self.collectionSubtype,
      assetIds: assetIds ?? self.assetIds,
    )
  }
}
