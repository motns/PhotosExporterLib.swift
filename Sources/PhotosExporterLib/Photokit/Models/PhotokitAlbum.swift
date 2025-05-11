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
  let folderId: String
  let collectionSubtype: PhotokitAssetCollectionSubType
  let assetIds: [String]
}