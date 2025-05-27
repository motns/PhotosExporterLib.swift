import Foundation
import GRDB

enum AssetType: Int, Sendable, Codable {
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

enum AssetLibrary: Int, Sendable, Codable {
  case personalLibrary = 1
  case sharedLibrary = 2
  case sharedAlbum = 3
}

struct ExportedAsset: Codable, Equatable, Hashable {
  let id: String
  let assetType: AssetType
  let assetLibrary: AssetLibrary
  let createdAt: Date?
  let updatedAt: Date?
  let importedAt: Date
  let isFavourite: Bool
  let geoLat: Double?
  let geoLong: Double?
  let cityId: Int64?
  let countryId: Int64?
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
    case geoLat = "geo_lat"
    case geoLong = "geo_long"
    case cityId = "city_id"
    case countryId = "country_id"
    case isDeleted = "is_deleted"
    case deletedAt = "deleted_at"
  }

  func needsUpdate(_ other: ExportedAsset) -> Bool {
    return self.isFavourite != other.isFavourite
      || self.geoLat != other.geoLat
      || self.geoLong != other.geoLong
      || self.cityId != other.cityId
      || self.countryId != other.countryId
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    return lhs.id == rhs.id
      && lhs.assetType == rhs.assetType
      && lhs.assetLibrary == rhs.assetLibrary
      && DateHelper.safeEquals(lhs.createdAt, rhs.createdAt)
      && DateHelper.safeEquals(lhs.updatedAt, rhs.updatedAt)
      && DateHelper.safeEquals(lhs.importedAt, rhs.importedAt)
      && lhs.isFavourite == rhs.isFavourite
      && lhs.geoLat == rhs.geoLat
      && lhs.geoLong == rhs.geoLong
      && lhs.cityId == rhs.cityId
      && lhs.countryId == rhs.countryId
      && lhs.isDeleted == rhs.isDeleted
      && DateHelper.safeEquals(lhs.deletedAt, rhs.deletedAt)
  }

  func copy(
    id: String? = nil,
    assetType: AssetType? = nil,
    assetLibrary: AssetLibrary? = nil,
    createdAt: Date?? = nil,
    updatedAt: Date?? = nil,
    importedAt: Date? = nil,
    isFavourite: Bool? = nil,
    geoLat: Double?? = nil,
    geoLong: Double?? = nil,
    cityId: Int64? = nil,
    countryId: Int64? = nil,
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
      geoLat: geoLat ?? self.geoLat,
      geoLong: geoLong ?? self.geoLong,
      cityId: cityId ?? self.cityId,
      countryId: countryId ?? self.countryId,
      isDeleted: isDeleted ?? self.isDeleted,
      deletedAt: deletedAt ?? self.deletedAt
    )
  }

  func updated(from: ExportedAsset) -> ExportedAsset {
    return self.copy(
      updatedAt: from.updatedAt,
      isFavourite: from.isFavourite,
      geoLat: from.geoLat,
      geoLong: from.geoLong,
      cityId: from.cityId,
      countryId: from.countryId,
      isDeleted: false, // Implicitly False, since we're updating from a Photokit Asset
      deletedAt: nil
    )
  }

  static func fromPhotokitAsset(
    asset: PhotokitAsset,
    cityId: Int64?,
    countryId: Int64?,
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
      createdAt: asset.createdAt,
      updatedAt: asset.updatedAt,
      importedAt: now,
      isFavourite: asset.isFavourite,
      geoLat: asset.geoLat,
      geoLong: asset.geoLong,
      cityId: cityId,
      countryId: countryId,
      isDeleted: false, // This is implicitly False, since we're creating it from a Photokit Asset
      deletedAt: nil
    )
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
    static let geoLat = Column(CodingKeys.geoLat)
    static let geoLong = Column(CodingKeys.geoLong)
    static let cityId = Column(CodingKeys.cityId)
    static let countryId = Column(CodingKeys.countryId)
    static let isDeleted = Column(CodingKeys.isDeleted)
    static let deletedAt = Column(CodingKeys.deletedAt)
  }

  static func createTable(_ db: Database) throws {
    try db.create(table: "asset") { table in
      table.primaryKey("id", .text).notNull()
      table.column("asset_type_id", .integer).notNull().references("asset_type")
      table.column("asset_library_id", .integer).notNull().references("asset_library")
      table.column("created_at", .datetime)
      table.column("updated_at", .datetime)
      table.column("imported_at", .datetime).notNull()
      table.column("is_favourite", .boolean).notNull()
      table.column("geo_lat", .double)
      table.column("geo_long", .double)
      table.column("country_id", .integer).references("country")
      table.column("city_id", .integer).references("city")
      table.column("is_deleted", .boolean).notNull()
      table.column("deleted_at", .datetime)
    }
  }
}
