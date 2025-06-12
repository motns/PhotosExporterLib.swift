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

struct ExportResultHistoryEntry: Codable {
  let id: String
  let createdAt: Date
  let exportResult: PhotosExporterLib.Result
  let assetCount: Int
  let fileCount: Int
  let albumCount: Int
  let folderCount: Int
  let fileSizeTotal: Int64
  let runTime: Decimal

  enum CodingKeys: String, CodingKey {
    case id
    case createdAt = "created_at"
    case exportResult = "export_result"
    case assetCount = "asset_count"
    case fileCount = "file_count"
    case albumCount = "album_count"
    case folderCount = "folder_count"
    case fileSizeTotal = "file_size_total"
    case runTime = "run_time"
  }

  func copy(
    id: String? = nil,
    createdAt: Date? = nil,
    exportResult: PhotosExporterLib.Result? = nil,
    assetCount: Int? = nil,
    fileCount: Int? = nil,
    albumCount: Int? = nil,
    folderCount: Int? = nil,
    fileSizeTotal: Int64? = nil,
    runTime: Decimal? = nil,
  ) -> ExportResultHistoryEntry {
    return ExportResultHistoryEntry(
      id: id ?? self.id,
      createdAt: createdAt ?? self.createdAt,
      exportResult: exportResult ?? self.exportResult,
      assetCount: assetCount ?? self.assetCount,
      fileCount: fileCount ?? self.fileCount,
      albumCount: albumCount ?? self.albumCount,
      folderCount: folderCount ?? self.folderCount,
      fileSizeTotal: fileSizeTotal ?? self.fileSizeTotal,
      runTime: runTime ?? self.runTime,
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
      fileSizeTotal: self.fileSizeTotal,
      runTime: self.runTime,
    )
  }

  // swiftlint:disable:next function_parameter_count
  static func fromExportResult(
    exportResult: PhotosExporterLib.Result,
    assetCount: Int,
    fileCount: Int,
    albumCount: Int,
    folderCount: Int,
    fileSizeTotal: Int64,
    now: Date,
    runTime: Decimal,
  ) -> ExportResultHistoryEntry {
    return ExportResultHistoryEntry(
      id: UUID().uuidString,
      createdAt: now,
      exportResult: exportResult,
      assetCount: assetCount,
      fileCount: fileCount,
      albumCount: albumCount,
      folderCount: folderCount,
      fileSizeTotal: fileSizeTotal,
      runTime: runTime,
    )
  }
}

extension ExportResultHistoryEntry: DiffableStruct {
  func getStructDiff(_ other: ExportResultHistoryEntry) -> StructDiff {
    return StructDiff()
      .add(diffProperty(other, \.id))
      .add(diffProperty(other, \.createdAt))
      .add(diffProperty(other, \.exportResult))
      .add(diffProperty(other, \.assetCount))
      .add(diffProperty(other, \.fileCount))
      .add(diffProperty(other, \.albumCount))
      .add(diffProperty(other, \.folderCount))
      .add(diffProperty(other, \.fileSizeTotal))
      .add(diffProperty(other, \.runTime))
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
    static let fileSizeTotal = Column(CodingKeys.fileSizeTotal)
    static let runTime = Column(CodingKeys.runTime)
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
      table.column("file_size_total", .integer).notNull()
      table.column("run_time", .text).notNull()
    }
  }
}

// Create a separate struct to avoid leaking out all of our
// internal implementation details
public struct HistoryEntry {
  let id: String
  let createdAt: Date
  let exportResult: PhotosExporterLib.Result
  let assetCount: Int
  let fileCount: Int
  let albumCount: Int
  let folderCount: Int
  let fileSizeTotal: Int64
  let runTime: Decimal
}

extension HistoryEntry: DiffableStruct {
  func getStructDiff(_ other: HistoryEntry) -> StructDiff {
    return StructDiff()
      .add(diffProperty(other, \.id))
      .add(diffProperty(other, \.createdAt))
      .add(diffProperty(other, \.exportResult))
      .add(diffProperty(other, \.assetCount))
      .add(diffProperty(other, \.fileCount))
      .add(diffProperty(other, \.albumCount))
      .add(diffProperty(other, \.folderCount))
      .add(diffProperty(other, \.fileSizeTotal))
      .add(diffProperty(other, \.runTime))
  }
}
