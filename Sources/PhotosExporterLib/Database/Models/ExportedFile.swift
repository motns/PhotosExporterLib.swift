import Foundation
import GRDB

enum FileType: Int, Sendable, Codable {
  case originalImage = 1
  case originalVideo = 2
  case originalAudio = 3
  case originalLiveVideo = 4
  case editedImage = 5
  case editedVideo = 6
  case editedLiveVideo = 7

  func isEdited() -> Bool {
    switch self {
    case .editedImage, .editedVideo, .editedLiveVideo: true
    default: false
    }
  }

  static func fromPhotokitAssetResourceType(
    _ assetResourceType: PhotokitAssetResourceType
  ) -> FileType? {
    return switch assetResourceType {
    case .photo: FileType.originalImage
    case .video: FileType.originalVideo
    case .audio: FileType.originalAudio
    case .pairedVideo: FileType.originalLiveVideo
    case .fullSizePhoto: FileType.editedImage
    case .fullSizeVideo: FileType.editedVideo
    case .fullSizePairedVideo: FileType.editedLiveVideo
    default: nil
    }
  }
}

struct ExportedFile: Codable, Equatable, Hashable {
  let assetId: String
  let fileType: FileType
  let originalFileName: String
  let importedAt: Date
  let importedFileDir: String
  let importedFileName: String
  let wasCopied: Bool
  let isDeleted: Bool
  let deletedAt: Date?

  enum CodingKeys: String, CodingKey {
    case assetId = "asset_id"
    case fileType = "file_type_id"
    case originalFileName = "original_file_name"
    case importedAt = "imported_at"
    case importedFileDir = "imported_file_dir"
    case importedFileName = "imported_file_name"
    case wasCopied = "was_copied"
    case isDeleted = "is_deleted"
    case deletedAt = "deleted_at"
  }

  func needsUpdate(_ other: ExportedFile) -> Bool {
    return self.importedFileDir != other.importedFileDir
      || self.importedFileName != other.importedFileName
      // It shouldn't be possible to unset the "copied" flag
      || (!self.wasCopied && other.wasCopied)
      || self.isDeleted != other.isDeleted
      || self.deletedAt != other.deletedAt
  }

  func updated(_ from: ExportedFile) -> ExportedFile {
    return self.copy(
      importedFileDir: from.importedFileDir,
      importedFileName: from.importedFileName,
      // It shouldn't normally be possible to unset the "copied" flag
      wasCopied: self.wasCopied || from.wasCopied,
      isDeleted: from.isDeleted,
      deletedAt: from.deletedAt,
    )
  }

  func copy(
    assetId: String? = nil,
    fileType: FileType? = nil,
    originalFileName: String? = nil,
    importedAt: Date? = nil,
    importedFileDir: String? = nil,
    importedFileName: String? = nil,
    wasCopied: Bool? = nil,
    isDeleted: Bool? = nil,
    deletedAt: Date?? = nil
  ) -> ExportedFile {
    return ExportedFile(
      assetId: assetId ?? self.assetId,
      fileType: fileType ?? self.fileType,
      originalFileName: originalFileName ?? self.originalFileName,
      importedAt: importedAt ?? self.importedAt,
      importedFileDir: importedFileDir ?? self.importedFileDir,
      importedFileName: importedFileName ?? self.importedFileName,
      wasCopied: wasCopied ?? self.wasCopied,
      isDeleted: isDeleted ?? self.isDeleted,
      deletedAt: deletedAt ?? self.deletedAt
    )
  }

  static func fromPhotokitAssetResource(
    asset: PhotokitAsset,
    resource: PhotokitAssetResource,
    countryOpt: String?,
    cityOpt: String?,
    now: Date?
  ) -> ExportedFile? {
    let fileTypeOpt = FileType.fromPhotokitAssetResourceType(resource.assetResourceType)
    guard let fileType = fileTypeOpt else {
      // We should never make it here
      // Unsupported types should be filtered upstream, but this is more graceful
      return nil
    }

    let isEdited = switch fileType {
    case .editedImage, .editedVideo, .editedLiveVideo: true
    default: false
    }

    return ExportedFile(
      assetId: resource.assetId,
      fileType: fileType,
      originalFileName: resource.originalFileName,
      importedAt: now ?? Date(),
      importedFileDir: FileHelper.pathForDateAndLocation(
        dateOpt: asset.createdAt,
        countryOpt: countryOpt,
        cityOpt: cityOpt
      ),
      importedFileName: FileHelper.filenameWithDateAndEdited(
        originalFileName: resource.originalFileName,
        dateOpt: asset.createdAt,
        isEdited: isEdited
      ),
      wasCopied: false,
      isDeleted: false, // Implicitly false
      deletedAt: nil
    )
  }
}

extension ExportedFile: TableRecord, PersistableRecord, FetchableRecord {
  static let databaseTableName = "file"

  enum Col {
    static let assetId = Column(CodingKeys.assetId)
    static let fileType = Column(CodingKeys.fileType)
    static let originalFileName = Column(CodingKeys.originalFileName)
    static let importedAt = Column(CodingKeys.importedAt)
    static let importedFileDir = Column(CodingKeys.importedFileDir)
    static let importedFileName = Column(CodingKeys.importedFileName)
    static let wasCopied = Column(CodingKeys.wasCopied)
    static let isDeleted = Column(CodingKeys.isDeleted)
    static let deletedAt = Column(CodingKeys.deletedAt)
  }
}
