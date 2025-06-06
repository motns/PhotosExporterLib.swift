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

enum FileType: Int, Sendable, Codable, SingleValueDiffable {
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

struct ExportedFile: Codable {
  let id: String
  let fileType: FileType
  let originalFileName: String
  let geoLat: Decimal?
  let geoLong: Decimal?
  let countryId: Int64?
  let cityId: Int64?
  let fileSize: Int64
  let pixelHeight: Int64
  let pixelWidth: Int64
  let importedAt: Date
  let importedFileDir: String
  let wasCopied: Bool

  enum CodingKeys: String, CodingKey {
    case id = "id"
    case fileType = "file_type_id"
    case originalFileName = "original_file_name"
    case geoLat = "geo_lat"
    case geoLong = "geo_long"
    case countryId = "country_id"
    case cityId = "city_id"
    case fileSize = "file_size"
    case pixelHeight = "pixel_height"
    case pixelWidth = "pixel_width"
    case importedAt = "imported_at"
    case importedFileDir = "imported_file_dir"
    case wasCopied = "was_copied"
  }

  func needsUpdate(_ other: ExportedFile) -> Bool {
    let newGeoLat = other.geoLat ?? self.geoLat
    let newGeoLong = other.geoLong ?? self.geoLong
    let newCountryId = other.countryId ?? self.countryId
    let newCityId = other.cityId ?? self.cityId

    let locationChanged = self.countryId != newCountryId
      || self.cityId != newCityId
    let newImportedFileDir = locationChanged ? other.importedFileDir : self.importedFileDir
    let newWasCopied = locationChanged ? false : (self.wasCopied || other.wasCopied)

    return self.importedFileDir != newImportedFileDir
      // It shouldn't be possible to unset the "copied" flag
      || self.wasCopied != newWasCopied
      || self.geoLat != newGeoLat
      || self.geoLong != newGeoLong
      || self.countryId != newCountryId
      || self.cityId != newCityId
  }

  func updated(_ from: ExportedFile) -> ExportedFile {
    let newGeoLat = from.geoLat ?? self.geoLat
    let newGeoLong = from.geoLong ?? self.geoLong
    let newCountryId = from.countryId ?? self.countryId
    let newCityId = from.cityId ?? self.cityId

    let locationChanged = self.countryId != newCountryId
      || self.cityId != newCityId
    let newImportedFileDir = locationChanged ? from.importedFileDir : self.importedFileDir
    let newWasCopied = locationChanged ? false : (self.wasCopied || from.wasCopied)

    return self.copy(
      geoLat: newGeoLat,
      geoLong: newGeoLong,
      countryId: newCountryId,
      cityId: newCityId,
      importedFileDir: newImportedFileDir,
      wasCopied: newWasCopied,
    )
  }

  func copy(
    id: String? = nil,
    fileType: FileType? = nil,
    originalFileName: String? = nil,
    geoLat: Decimal?? = nil,
    geoLong: Decimal?? = nil,
    countryId: Int64?? = nil,
    cityId: Int64?? = nil,
    fileSize: Int64? = nil,
    pixelHeight: Int64? = nil,
    pixelWidth: Int64? = nil,
    importedAt: Date? = nil,
    importedFileDir: String? = nil,
    wasCopied: Bool? = nil,
  ) -> ExportedFile {
    return ExportedFile(
      id: id ?? self.id,
      fileType: fileType ?? self.fileType,
      originalFileName: originalFileName ?? self.originalFileName,
      geoLat: geoLat ?? self.geoLat,
      geoLong: geoLong ?? self.geoLong,
      countryId: countryId ?? self.countryId,
      cityId: cityId ?? self.cityId,
      fileSize: fileSize ?? self.fileSize,
      pixelHeight: pixelHeight ?? self.pixelHeight,
      pixelWidth: pixelWidth ?? self.pixelWidth,
      importedAt: importedAt ?? self.importedAt,
      importedFileDir: importedFileDir ?? self.importedFileDir,
      wasCopied: wasCopied ?? self.wasCopied,
    )
  }

  static func generateId(
    assetCreatedAt: Date?,
    fileSize: Int64,
    fileType: FileType?,
    originalFileName: String,
  ) -> String {
    let prefix: String
    if let date = assetCreatedAt {
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyyMMddHHmmss"
      prefix = formatter.string(from: date)
    } else {
      prefix = "00000000000000"
    }

    let fileURL = URL(filePath: originalFileName)
    let name = FileHelper.normaliseForPath(fileURL.deletingPathExtension().lastPathComponent)
    let ext = fileURL.pathExtension.lowercased()
    let suffix = (fileType?.isEdited() ?? false) ? "_edited" : ""

    return "\(prefix)-\(fileSize)-\(name)\(suffix).\(ext)"
  }

  static func generateId(
    asset: PhotokitAsset,
    resource: PhotokitAssetResource,
  ) -> String {
    return generateId(
      assetCreatedAt: asset.createdAt,
      fileSize: resource.fileSize,
      fileType: FileType.fromPhotokitAssetResourceType(
        resource.assetResourceType
      ),
      originalFileName: resource.originalFileName,
    )
  }

  // swiftlint:disable:next function_parameter_count
  static func fromPhotokitAssetResource(
    asset: PhotokitAsset,
    resource: PhotokitAssetResource,
    now: Date,
    countryId: Int64?,
    cityId: Int64?,
    country: String?,
    city: String?,
  ) -> ExportedFile? {
    let fileTypeOpt = FileType.fromPhotokitAssetResourceType(resource.assetResourceType)
    guard let fileType = fileTypeOpt else {
      // We should never make it here
      // Unsupported types should be filtered upstream, but this is more graceful
      return nil
    }

    return ExportedFile(
      id: generateId(asset: asset, resource: resource),
      fileType: fileType,
      originalFileName: resource.originalFileName,
      geoLat: asset.geoLat,
      geoLong: asset.geoLong,
      countryId: countryId,
      cityId: cityId,
      fileSize: resource.fileSize,
      pixelHeight: resource.pixelHeight,
      pixelWidth: resource.pixelWidth,
      importedAt: now,
      importedFileDir: FileHelper.pathForDateAndLocation(
        date: asset.createdAt,
        country: country,
        city: city,
      ),
      wasCopied: false,
    )
  }
}

extension ExportedFile: DiffableStruct {
  func getStructDiff(_ other: ExportedFile) -> StructDiff {
    return StructDiff()
      .add(diffProperty(other, \.id))
      .add(diffProperty(other, \.fileType))
      .add(diffProperty(other, \.originalFileName))
      .add(diffProperty(other, \.geoLat))
      .add(diffProperty(other, \.geoLong))
      .add(diffProperty(other, \.countryId))
      .add(diffProperty(other, \.cityId))
      .add(diffProperty(other, \.fileSize))
      .add(diffProperty(other, \.pixelHeight))
      .add(diffProperty(other, \.pixelWidth))
      .add(diffProperty(other, \.importedAt))
      .add(diffProperty(other, \.importedFileDir))
      .add(diffProperty(other, \.wasCopied))
  }
}

extension ExportedFile: Identifiable, TableRecord, PersistableRecord, FetchableRecord {
  static let databaseTableName = "file"

  enum Columns {
    static let id = Column(CodingKeys.id)
    static let fileType = Column(CodingKeys.fileType)
    static let originalFileName = Column(CodingKeys.originalFileName)
    static let geoLat = Column(CodingKeys.geoLat)
    static let geoLong = Column(CodingKeys.geoLong)
    static let countryId = Column(CodingKeys.countryId)
    static let cityId = Column(CodingKeys.cityId)
    static let fileSize = Column(CodingKeys.fileSize)
    static let pixelHeight = Column(CodingKeys.pixelHeight)
    static let pixelWidth = Column(CodingKeys.pixelWidth)
    static let importedAt = Column(CodingKeys.importedAt)
    static let importedFileDir = Column(CodingKeys.importedFileDir)
    static let wasCopied = Column(CodingKeys.wasCopied)
  }

  static func createTable(_ db: Database) throws {
    try db.create(table: databaseTableName) { table in
      table.primaryKey("id", .text).notNull()
      table.column("file_type_id", .integer).notNull().references("file_type")
      table.column("original_file_name", .text).notNull()
      table.column("geo_lat", .text)
      table.column("geo_long", .text)
      table.column("country_id", .integer).references("country")
      table.column("city_id", .integer).references("city")
      table.column("file_size", .integer).notNull()
      table.column("pixel_height", .integer).notNull()
      table.column("pixel_width", .integer).notNull()
      table.column("imported_at", .datetime).notNull()
      table.column("imported_file_dir", .text).notNull()
      table.column("was_copied", .boolean).notNull()
    }
  }
}
