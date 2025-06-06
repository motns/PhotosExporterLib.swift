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

enum PhotokitAssetMediaType: Int, Sendable, SingleValueDiffable {
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
  let geoLat: Decimal?
  let geoLong: Decimal?
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
    geoLat: Decimal?? = nil,
    geoLong: Decimal?? = nil,
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
      geoLat: asset.location.map { loc in
        Decimal(loc.coordinate.latitude).rounded(scale: 6)
      },
      geoLong: asset.location.map { loc in
        Decimal(loc.coordinate.longitude).rounded(scale: 6)
      },
      resources: resources,
    )
  }
}

extension PhotokitAsset: DiffableStruct {
  func getStructDiff(_ other: PhotokitAsset) -> StructDiff {
    return StructDiff()
      .add(diffProperty(other, \.id))
      .add(diffProperty(other, \.assetMediaType))
      .add(diffProperty(other, \.assetLibrary))
      .add(diffProperty(other, \.createdAt))
      .add(diffProperty(other, \.updatedAt))
      .add(diffProperty(other, \.isFavourite))
      .add(diffProperty(other, \.geoLat))
      .add(diffProperty(other, \.geoLong))
      .add(diffProperty(other, \.resources))
  }
}
