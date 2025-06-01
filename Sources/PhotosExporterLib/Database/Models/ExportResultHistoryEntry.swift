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

struct ExportResultHistoryEntry: Codable, Equatable {
  let id: String
  let createdAt: Date
  let exportResult: ExportResult
  let assetCount: Int
  let fileCount: Int
  let albumCount: Int
  let folderCount: Int

  enum CodingKeys: String, CodingKey {
    case id
    case createdAt = "created_at"
    case exportResult = "export_result"
    case assetCount = "asset_count"
    case fileCount = "file_count"
    case albumCount = "album_count"
    case folderCount = "folder_count"
  }

  func copy(
    id: String? = nil,
    createdAt: Date? = nil,
    exportResult: ExportResult? = nil,
    assetCount: Int? = nil,
    fileCount: Int? = nil,
    albumCount: Int? = nil,
    folderCount: Int? = nil,
  ) -> ExportResultHistoryEntry {
    return ExportResultHistoryEntry(
      id: id ?? self.id,
      createdAt: createdAt ?? self.createdAt,
      exportResult: exportResult ?? self.exportResult,
      assetCount: assetCount ?? self.assetCount,
      fileCount: fileCount ?? self.fileCount,
      albumCount: albumCount ?? self.albumCount,
      folderCount: folderCount ?? self.folderCount,
    )
  }

  func toPublicEntry() -> HistoryEntry {
    return HistoryEntry(
      id: self.id,
      createdAt: self.createdAt,
      exportResult: self.exportResult,
      assetCount: self.assetCount,
      fileCount: self.fileCount,
      albumCount: self.albumCount,
      folderCount: self.folderCount,
    )
  }

  static func == (lhs: ExportResultHistoryEntry, rhs: ExportResultHistoryEntry) -> Bool {
    return lhs.id == rhs.id
      && DateHelper.secondsEquals(lhs.createdAt, rhs.createdAt)
      && lhs.exportResult == rhs.exportResult
      && lhs.assetCount == rhs.assetCount
      && lhs.fileCount == rhs.fileCount
      && lhs.albumCount == rhs.albumCount
      && lhs.folderCount == rhs.folderCount
  }

  static func fromExportResult(
    exportResult: ExportResult,
    assetCount: Int,
    fileCount: Int,
    albumCount: Int,
    folderCount: Int,
    now: Date? = nil,
  ) -> ExportResultHistoryEntry {
    return ExportResultHistoryEntry(
      id: UUID().uuidString,
      createdAt: now ?? Date(),
      exportResult: exportResult,
      assetCount: assetCount,
      fileCount: fileCount,
      albumCount: albumCount,
      folderCount: folderCount,
    )
  }
}

extension ExportResultHistoryEntry: Identifiable, FetchableRecord, PersistableRecord, TableRecord {
  static let databaseTableName = "export_result_history"

  enum Columns {
    static let id = Column(CodingKeys.id)
    static let createdAt = Column(CodingKeys.createdAt)
    static let exportResult = Column(CodingKeys.exportResult)
    static let assetCount = Column(CodingKeys.assetCount)
    static let fileCount = Column(CodingKeys.fileCount)
    static let albumCount = Column(CodingKeys.albumCount)
    static let folderCount = Column(CodingKeys.folderCount)
  }

  static func createTable(_ db: Database) throws {
    try db.create(table: databaseTableName) { table in
      table.primaryKey("id", .text).notNull()
      table.column("created_at", .datetime).notNull()
      table.column("export_result", .jsonText).notNull()
      table.column("asset_count", .integer).notNull()
      table.column("file_count", .integer).notNull()
      table.column("album_count", .integer).notNull()
      table.column("folder_count", .integer).notNull()
    }
  }
}

// Create a separate struct to avoid leaking out all of our
// internal implementation details
public struct HistoryEntry {
  let id: String
  let createdAt: Date
  let exportResult: ExportResult
  let assetCount: Int
  let fileCount: Int
  let albumCount: Int
  let folderCount: Int
}
