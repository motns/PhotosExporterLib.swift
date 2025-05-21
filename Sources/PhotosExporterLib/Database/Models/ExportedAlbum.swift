import Foundation
import GRDB

enum AlbumType: Int, Sendable, Codable {
  case user = 1
  case shared = 2
}

struct ExportedAlbum: Codable, Equatable, Hashable {
  let id: String
  let albumType: AlbumType
  let albumFolderId: String
  let name: String
  let assetIds: Set<String>

  enum CodingKeys: String, CodingKey {
    case id, name
    case albumType = "album_type_id"
    case albumFolderId = "album_folder_id"
    case assetIds = "asset_ids"
  }

  func copy(
    id: String? = nil,
    albumType: AlbumType? = nil,
    albumFolderId: String? = nil,
    name: String? = nil,
    assetIds: Set<String>? = nil
  ) -> ExportedAlbum {
    return ExportedAlbum(
      id: id ?? self.id,
      albumType: albumType ?? self.albumType,
      albumFolderId: albumFolderId ?? self.albumFolderId,
      name: name ?? self.name,
      assetIds: assetIds ?? self.assetIds
    )
  }

  func needsUpdate(_ other: ExportedAlbum) -> Bool {
    return self.name != other.name ||
      self.albumFolderId != other.albumFolderId ||
      self.assetIds != other.assetIds
  }

  func updated(_ other: ExportedAlbum) -> ExportedAlbum {
    return self.copy(
      albumFolderId: other.albumFolderId,
      name: other.name,
      assetIds: other.assetIds
    )
  }

  static func fromPhotokitAlbum(album: PhotokitAlbum) throws -> ExportedAlbum {
    let albumType: AlbumType = switch album.collectionSubtype {
    case .albumRegular: .user
    case .albumCloudShared: .shared
    case let collectionSubtype:
      throw ExporterDBError.unsupportedAlbumType(String(describing: collectionSubtype))
    }

    return ExportedAlbum(
      id: album.id,
      albumType: albumType,
      albumFolderId: album.folderId,
      name: album.title,
      assetIds: Set(album.assetIds)
    )
  }
}

extension ExportedAlbum: Identifiable, TableRecord, PersistableRecord, FetchableRecord {
  static let databaseTableName = "album"

  enum Columns {
    static let id = Column(CodingKeys.id)
    static let name = Column(CodingKeys.name)
    static let albumType = Column(CodingKeys.albumType)
    static let albumFolderId = Column(CodingKeys.albumFolderId)
    static let assetIds = Column(CodingKeys.assetIds)
  }

  static func createTable(_ db: Database) throws {
    try db.create(table: "album") { table in
      table.primaryKey("id", .text).notNull()
      table.column("album_type_id", .integer).notNull().references("album_type")
      table.column("album_folder_id", .text).notNull().references("album_folder")
      table.column("name", .text).notNull()
      table.column("asset_ids", .jsonb).notNull()
    }

    try db.create(indexOn: "album", columns: ["album_folder_id"])
  }
}
