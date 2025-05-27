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

  func copy(
    id: String? = nil,
    assetMediaType: PhotokitAssetMediaType? = nil,
    assetLibrary: AssetLibrary? = nil,
    createdAt: Date?? = nil,
    updatedAt: Date?? = nil,
    isFavourite: Bool? = nil,
    geoLat: Double?? = nil,
    geoLong: Double?? = nil,
    resources: [PhotokitAssetResource]? = nil
  ) -> PhotokitAsset {
    PhotokitAsset(
      id: id ?? self.id,
      assetMediaType: assetMediaType ?? self.assetMediaType,
      assetLibrary: assetLibrary ?? self.assetLibrary,
      createdAt: createdAt ?? self.createdAt,
      updatedAt: updatedAt ?? self.updatedAt,
      isFavourite: isFavourite ?? self.isFavourite,
      geoLat: geoLat ?? self.geoLat,
      geoLong: geoLong ?? self.geoLong,
      resources: resources ?? self.resources,
    )
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
