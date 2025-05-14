import Foundation
import Photos

enum PhotokitAssetMediaType: Int, Sendable {
  case unknown = 0
  case image = 1
  case video = 2
  case audio = 3

  static func fromPHAssetMediaType(_ amt: PHAssetMediaType) -> PhotokitAssetMediaType {
    return switch amt {
    case .unknown: self.unknown
    case .image: self.image
    case .video: self.video
    case .audio: self.audio
    @unknown default: fatalError("Unknown PHAssetMediaType: \(amt)")
    }
  }
}

struct PhotokitAsset: Sendable {
  let id: String
  let assetMediaType: PhotokitAssetMediaType
  let assetLibrary: AssetLibrary
  let createdAt: Date?
  let updatedAt: Date?
  let isFavourite: Bool
  let geoLat: Double?
  let geoLong: Double?
  let resources: [PhotokitAssetResource]

  var uuid: String {
    String(id.split(separator: "/").first!)
  }

  static func fromPHAsset(
    asset: PHAsset,
    library: AssetLibrary,
    resources: [PhotokitAssetResource]
  ) -> PhotokitAsset {
    return PhotokitAsset(
      id: asset.localIdentifier,
      assetMediaType: PhotokitAssetMediaType.fromPHAssetMediaType(
        asset.mediaType
      ),
      assetLibrary: library,
      createdAt: asset.creationDate,
      updatedAt: asset.modificationDate,
      isFavourite: asset.isFavorite,
      geoLat: asset.location?.coordinate.latitude,
      geoLong: asset.location?.coordinate.longitude,
      resources: resources,
    )
  }
}
