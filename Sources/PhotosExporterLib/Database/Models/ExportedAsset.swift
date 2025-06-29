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
import GRDB

enum AssetType: Int, Sendable, Codable, SingleValueDiffable {
  case image = 1
  case video = 2
  case audio = 3

  static func fromPhotokitAssetMediaType(_ pat: PhotokitAssetMediaType) -> AssetType? {
    return switch pat {
    case .image: self.image
    case .video: self.video
    case .audio: self.audio
    case .unknown: nil
    }
  }
}

enum AssetLibrary: Int, Sendable, Codable, SingleValueDiffable {
  case personalLibrary = 1
  case sharedLibrary = 2
  case sharedAlbum = 3
}

struct ExportedAsset: Codable {
  let id: String
  let assetType: AssetType
  let assetLibrary: AssetLibrary
  let createdAt: Date?
  let updatedAt: Date?
  let importedAt: Date
  let isFavourite: Bool
  let aestheticScore: Int64
  let isDeleted: Bool
  let deletedAt: Date?

  enum CodingKeys: String, CodingKey {
    case id
    case assetType = "asset_type_id"
    case assetLibrary = "asset_library_id"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
    case importedAt = "imported_at"
    case isFavourite = "is_favourite"
    case aestheticScore = "aesthetic_score"
    case isDeleted = "is_deleted"
    case deletedAt = "deleted_at"
  }

  func needsUpdate(_ other: ExportedAsset) -> Bool {
    return !DateHelper.secondsEquals(self.updatedAt, other.updatedAt)
      || self.isFavourite != other.isFavourite
      || self.aestheticScore != other.aestheticScore
  }

  func copy(
    id: String? = nil,
    assetType: AssetType? = nil,
    assetLibrary: AssetLibrary? = nil,
    createdAt: Date?? = nil,
    updatedAt: Date?? = nil,
    importedAt: Date? = nil,
    isFavourite: Bool? = nil,
    aestheticScore: Int64? = nil,
    isDeleted: Bool? = nil,
    deletedAt: Date? = nil,
  ) -> ExportedAsset {
    return ExportedAsset(
      id: id ?? self.id,
      assetType: assetType ?? self.assetType,
      assetLibrary: assetLibrary ?? self.assetLibrary,
      createdAt: createdAt ?? self.createdAt,
      updatedAt: updatedAt ?? self.updatedAt,
      importedAt: importedAt ?? self.importedAt,
      isFavourite: isFavourite ?? self.isFavourite,
      aestheticScore: aestheticScore ?? self.aestheticScore,
      isDeleted: isDeleted ?? self.isDeleted,
      deletedAt: deletedAt ?? self.deletedAt
    )
  }

  func updated(from: ExportedAsset) -> ExportedAsset {
    return self.copy(
      updatedAt: from.updatedAt,
      isFavourite: from.isFavourite,
      aestheticScore: from.aestheticScore,
      isDeleted: false, // Implicitly False, since we're updating from a Photokit Asset
      deletedAt: nil
    )
  }

  static func fromPhotokitAsset(
    asset: PhotokitAsset,
    aestheticScore: Int64,
    now: Date
  ) -> ExportedAsset? {
    guard let assetType = AssetType.fromPhotokitAssetMediaType(asset.assetMediaType) else {
      // We should never make it here
      // Unsupported types should be filtered upstream, but this is more graceful
      return nil
    }

    return ExportedAsset(
      id: asset.id,
      assetType: assetType,
      assetLibrary: asset.assetLibrary,
      createdAt: asset.createdAt.map { date in
        DateHelper.truncateToSeconds(date)
      },
      updatedAt: asset.updatedAt.map { date in
        DateHelper.truncateToSeconds(date)
      },
      importedAt: now,
      isFavourite: asset.isFavourite,
      aestheticScore: aestheticScore,
      isDeleted: false, // This is implicitly False, since we're creating it from a Photokit Asset
      deletedAt: nil
    )
  }
}

extension ExportedAsset: DiffableStruct {
  func getStructDiff(_ other: ExportedAsset) -> StructDiff {
    return StructDiff()
      .add(diffProperty(other, \.id))
      .add(diffProperty(other, \.assetType))
      .add(diffProperty(other, \.assetLibrary))
      .add(diffProperty(other, \.createdAt))
      .add(diffProperty(other, \.updatedAt))
      .add(diffProperty(other, \.importedAt))
      .add(diffProperty(other, \.isFavourite))
      .add(diffProperty(other, \.aestheticScore))
      .add(diffProperty(other, \.isDeleted))
      .add(diffProperty(other, \.deletedAt))
  }
}

extension ExportedAsset: Identifiable, TableRecord, PersistableRecord, FetchableRecord {
  static let databaseTableName = "asset"

  enum Columns {
    static let id = Column(CodingKeys.id)
    static let assetType = Column(CodingKeys.assetType)
    static let createdAt = Column(CodingKeys.createdAt)
    static let updatedAt = Column(CodingKeys.updatedAt)
    static let importedAt = Column(CodingKeys.importedAt)
    static let isFavourite = Column(CodingKeys.isFavourite)
    static let aestheticScore = Column(CodingKeys.aestheticScore)
    static let isDeleted = Column(CodingKeys.isDeleted)
    static let deletedAt = Column(CodingKeys.deletedAt)
  }

  static func createTable(_ db: Database) throws {
    try db.create(table: databaseTableName) { table in
      table.primaryKey("id", .text).notNull()
      table.column("asset_type_id", .integer).notNull().references("asset_type")
      table.column("asset_library_id", .integer).notNull().references("asset_library")
      table.column("created_at", .datetime)
      table.column("updated_at", .datetime)
      table.column("imported_at", .datetime).notNull()
      table.column("is_favourite", .boolean).notNull()
      table.column("aesthetic_score", .integer).notNull()
      table.column("is_deleted", .boolean).notNull()
      table.column("deleted_at", .datetime)
    }
  }
}
