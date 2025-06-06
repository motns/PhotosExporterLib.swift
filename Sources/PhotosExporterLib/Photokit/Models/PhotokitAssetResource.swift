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

// Copy this Enum so that we can avoid leaking Photokit types into the rest
// of our library code
enum PhotokitAssetResourceType: Int, Sendable, SingleValueDiffable {
  case photo = 1
  case video = 2
  case audio = 3
  case alternatePhoto = 4
  case fullSizePhoto = 5
  case fullSizeVideo = 6
  case adjustmentData = 7
  case adjustmentBasePhoto = 8
  case pairedVideo = 9
  case fullSizePairedVideo = 10
  case adjustmentBasePairedVideo = 11
  case adjustmentBaseVideo = 12
  // This is undocumented and doesn't appear in reference files.
  // Comes up for ".aae" files, whereas `adjustmentData` only
  // seems to apply to "Adjustment.plist" files...
  case adjustmentAAE = 16
  case photoProxy = 19
  // Also undocumented and doesn't appear in reference files,
  // but seems to come up with markups are applied to an image.
  // No idea what it's called, but the Resource it was linked to was named
  // "AdjustmentsSecondary.data".
  case secondaryAdjustmentData = 110

  // swiftlint:disable:next cyclomatic_complexity
  func toPHAssetResourceType() -> PHAssetResourceType {
    return switch self {
    case .photo: PHAssetResourceType.photo
    case .video: PHAssetResourceType.video
    case .audio: PHAssetResourceType.audio
    case .alternatePhoto: PHAssetResourceType.alternatePhoto
    case .fullSizePhoto: PHAssetResourceType.fullSizePhoto
    case .fullSizeVideo: PHAssetResourceType.fullSizeVideo
    case .adjustmentData: PHAssetResourceType.adjustmentData
    case .adjustmentBasePhoto: PHAssetResourceType.adjustmentBasePhoto
    case .pairedVideo: PHAssetResourceType.pairedVideo
    case .fullSizePairedVideo: PHAssetResourceType.fullSizePairedVideo
    case .adjustmentBasePairedVideo: PHAssetResourceType.adjustmentBasePairedVideo
    case .adjustmentBaseVideo: PHAssetResourceType.adjustmentBaseVideo
    case .photoProxy: PHAssetResourceType.photoProxy
    case .adjustmentAAE: PHAssetResourceType.adjustmentData // Maybe?
    case .secondaryAdjustmentData: PHAssetResourceType.adjustmentData // Maybe?
    }
  }

  // swiftlint:disable:next cyclomatic_complexity
  static func fromPHAssetResourceType(assetResourceType: PHAssetResourceType) -> PhotokitAssetResourceType {
    return switch assetResourceType {
    case .photo: PhotokitAssetResourceType.photo
    case .video: PhotokitAssetResourceType.video
    case .audio: PhotokitAssetResourceType.audio
    case .alternatePhoto: PhotokitAssetResourceType.alternatePhoto
    case .fullSizePhoto: PhotokitAssetResourceType.fullSizePhoto
    case .fullSizeVideo: PhotokitAssetResourceType.fullSizeVideo
    case .adjustmentData: PhotokitAssetResourceType.adjustmentData
    case .adjustmentBasePhoto: PhotokitAssetResourceType.adjustmentBasePhoto
    case .pairedVideo: PhotokitAssetResourceType.pairedVideo
    case .fullSizePairedVideo: PhotokitAssetResourceType.fullSizePairedVideo
    case .adjustmentBasePairedVideo: PhotokitAssetResourceType.adjustmentBasePairedVideo
    case .adjustmentBaseVideo: PhotokitAssetResourceType.adjustmentBaseVideo
    case .photoProxy: PhotokitAssetResourceType.photoProxy
    // As noted above, this is not documented, and also doesn't exist in the
    // Swift library code it seems, so this is our sensible fallback...
    // Don't want to change the default case, so we can pick up legitimate
    // cases that we don't currently handle, in the future.
    case let type where type.rawValue == 110: PhotokitAssetResourceType.secondaryAdjustmentData
    // Same as above
    case let type where type.rawValue == 16: PhotokitAssetResourceType.adjustmentAAE
    @unknown default: fatalError("Unhandled PHAssetResourceType: \(assetResourceType)")
    }
  }

  static func fromExporterFileType(fileType: FileType) -> PhotokitAssetResourceType {
    return switch fileType {
    case .originalImage: .photo
    case .originalVideo: .video
    case .originalAudio: .audio
    case .originalLiveVideo: .pairedVideo
    case .editedImage: .fullSizePhoto
    case .editedVideo: .fullSizeVideo
    case .editedLiveVideo: .fullSizePairedVideo
    }
  }
}

struct PhotokitAssetResource: Sendable {
  let assetResourceType: PhotokitAssetResourceType
  let originalFileName: String
  let fileSize: Int64
  let pixelHeight: Int64
  let pixelWidth: Int64

  static func fromPHAssetResource(
    resource: PHAssetResource,
    fileSize: Int64,
  ) -> PhotokitAssetResource {
    return PhotokitAssetResource(
      assetResourceType: PhotokitAssetResourceType.fromPHAssetResourceType(assetResourceType: resource.type),
      originalFileName: resource.originalFilename,
      fileSize: fileSize,
      pixelHeight: Int64(resource.pixelHeight),
      pixelWidth: Int64(resource.pixelWidth),
    )
  }
}

extension PhotokitAssetResource: DiffableStruct {
  func getStructDiff(_ other: PhotokitAssetResource) -> StructDiff {
    return StructDiff()
      .add(diffProperty(other, \.assetResourceType))
      .add(diffProperty(other, \.originalFileName))
      .add(diffProperty(other, \.fileSize))
      .add(diffProperty(other, \.pixelHeight))
      .add(diffProperty(other, \.pixelWidth))
  }
}
