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
      || !DateHelper.secondsEquals(self.deletedAt, other.deletedAt)
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
    try db.create(table: databaseTableName) { table in
      table.column("asset_id", .text).notNull().references("asset")
      table.column("file_id", .text).notNull().references("file")
      table.primaryKey(["asset_id", "file_id"])
      table.column("is_deleted", .boolean).notNull()
      table.column("deleted_at", .datetime)
    }
  }
}
