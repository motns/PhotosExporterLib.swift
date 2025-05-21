import GRDB
import Foundation

struct ExportedAssetFile: Codable, Equatable {
  let assetId: String
  let fileId: String
  let isDeleted: Bool
  let deletedAt: Date?

  enum CodingKeys: String, CodingKey {
  case assetId = "asset_id"
  case fileId = "file_id"
  case isDeleted = "is_deleted"
  case deletedAt = "deleted_at"
  }

  func needsUpdate(_ other: ExportedAssetFile) -> Bool {
    return self.isDeleted != other.isDeleted
      || self.deletedAt != other.deletedAt
  }

  func updated(_ from: ExportedAssetFile) -> ExportedAssetFile {
    return self.copy(
      isDeleted: from.isDeleted,
      deletedAt: from.deletedAt,
    )
  }

  func copy(
    assetId: String? = nil,
    fileId: String? = nil,
    isDeleted: Bool? = nil,
    deletedAt: Date?? = nil,
  ) -> ExportedAssetFile {
    return ExportedAssetFile(
      assetId: assetId ?? self.assetId,
      fileId: fileId ?? self.fileId,
      isDeleted: isDeleted ?? self.isDeleted,
      deletedAt: deletedAt ?? self.deletedAt,
    )
  }
}

extension ExportedAssetFile: TableRecord, PersistableRecord, FetchableRecord {
  static let databaseTableName = "asset_file"

  enum Columns {
    static let assetId = Column(CodingKeys.assetId)
    static let fileId = Column(CodingKeys.fileId)
    static let isDeleted = Column(CodingKeys.isDeleted)
    static let deletedAt = Column(CodingKeys.deletedAt)
  }

  static func createTable(_ db: Database) throws {
    try db.create(table: "asset_file") { table in
      table.column("asset_id", .text).notNull().references("asset")
      table.column("file_id", .text).notNull().references("file")
      table.primaryKey(["asset_id", "file_id"])
      table.column("is_deleted", .boolean).notNull()
      table.column("deleted_at", .datetime)
    }
  }
}
