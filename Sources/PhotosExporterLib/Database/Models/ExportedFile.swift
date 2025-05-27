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
  let id: String
  let fileType: FileType
  let originalFileName: String
  let fileSize: Int64
  let importedAt: Date
  let importedFileDir: String
  let importedFileName: String
  let wasCopied: Bool

  enum CodingKeys: String, CodingKey {
    case id = "id"
    case fileType = "file_type_id"
    case originalFileName = "original_file_name"
    case fileSize = "file_size"
    case importedAt = "imported_at"
    case importedFileDir = "imported_file_dir"
    case importedFileName = "imported_file_name"
    case wasCopied = "was_copied"
  }

  func needsUpdate(_ other: ExportedFile) -> Bool {
    let newWasCopied: Bool
    if self.importedFileDir != other.importedFileDir
    || self.importedFileName != other.importedFileName {
      // The output location changed, so the file needs to
      // be copied again
      newWasCopied = false
    } else {
      // Otherwise it shouldn't normally be possible to
      // unset the "copied" flag
      newWasCopied = self.wasCopied || other.wasCopied
    }

    return self.importedFileDir != other.importedFileDir
      || self.importedFileName != other.importedFileName
      || self.fileSize != other.fileSize
      // It shouldn't be possible to unset the "copied" flag
      || self.wasCopied != newWasCopied
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    return lhs.id == rhs.id
      && lhs.fileType == rhs.fileType
      && lhs.originalFileName == rhs.originalFileName
      && lhs.fileSize == rhs.fileSize
      && DateHelper.safeEquals(lhs.importedAt, rhs.importedAt)
      && lhs.importedFileDir == rhs.importedFileDir
      && lhs.importedFileName == rhs.importedFileName
      && lhs.wasCopied == rhs.wasCopied
  }

  func updated(_ from: ExportedFile) -> ExportedFile {
    let newWasCopied: Bool
    if self.importedFileDir != from.importedFileDir
    || self.importedFileName != from.importedFileName {
      // The output location changed, so the file needs to
      // be copied again
      newWasCopied = false
    } else {
      // Otherwise it shouldn't normally be possible to
      // unset the "copied" flag
      newWasCopied = self.wasCopied || from.wasCopied
    }

    return self.copy(
      fileSize: from.fileSize,
      importedFileDir: from.importedFileDir,
      importedFileName: from.importedFileName,
      // It shouldn't normally be possible to unset the "copied" flag
      wasCopied: newWasCopied,
    )
  }

  func copy(
    id: String? = nil,
    fileType: FileType? = nil,
    originalFileName: String? = nil,
    fileSize: Int64? = nil,
    importedAt: Date? = nil,
    importedFileDir: String? = nil,
    importedFileName: String? = nil,
    wasCopied: Bool? = nil,
  ) -> ExportedFile {
    return ExportedFile(
      id: id ?? self.id,
      fileType: fileType ?? self.fileType,
      originalFileName: originalFileName ?? self.originalFileName,
      fileSize: fileSize ?? self.fileSize,
      importedAt: importedAt ?? self.importedAt,
      importedFileDir: importedFileDir ?? self.importedFileDir,
      importedFileName: importedFileName ?? self.importedFileName,
      wasCopied: wasCopied ?? self.wasCopied,
    )
  }

  static func fromPhotokitAssetResource(
    asset: PhotokitAsset,
    resource: PhotokitAssetResource,
    countryOpt: String?,
    cityOpt: String?,
    now: Date?,
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

    let datePrefix: String
    if let date = asset.createdAt {
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyyMMddHHmmss"
      datePrefix = formatter.string(from: date)
    } else {
      datePrefix = "00000000000000"
    }

    return ExportedFile(
      id: "\(datePrefix)-\(resource.fileSize)-\(resource.originalFileName)",
      fileType: fileType,
      originalFileName: resource.originalFileName,
      fileSize: resource.fileSize,
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
    )
  }
}

extension ExportedFile: Identifiable, TableRecord, PersistableRecord, FetchableRecord {
  static let databaseTableName = "file"

  enum Columns {
    static let id = Column(CodingKeys.id)
    static let fileType = Column(CodingKeys.fileType)
    static let originalFileName = Column(CodingKeys.originalFileName)
    static let importedAt = Column(CodingKeys.importedAt)
    static let importedFileDir = Column(CodingKeys.importedFileDir)
    static let importedFileName = Column(CodingKeys.importedFileName)
    static let wasCopied = Column(CodingKeys.wasCopied)
  }

  static func createTable(_ db: Database) throws {
    try db.create(table: "file") { table in
      table.primaryKey("id", .text).notNull()
      table.column("file_type_id", .integer).notNull().references("file_type")
      table.column("original_file_name", .text).notNull()
      table.column("file_size", .integer).notNull()
      table.column("imported_at", .datetime).notNull()
      table.column("imported_file_dir", .text).notNull()
      table.column("imported_file_name", .text).notNull()
      table.column("was_copied", .boolean).notNull()
    }
  }
}
