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
@testable import PhotosExporterLib

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
struct TestDataGenerator {
  let exporterDB: ExporterDB

  // 2010-03-20 15:45:04
  let defaultDateStart: Int = 1269099904
  // 2025-03-20 15:45:04
  let defaultDateEnd: Int = 1742485504

  func createPostalAddress(
    country: String? = nil,
    city: String? = nil,
  ) -> PhotosDB.PostalAddress {
    return PhotosDB.PostalAddress(
      street: "",
      subLocality: "",
      city: city ?? "London",
      subAdministrativeArea: "",
      state: "",
      postalCode: "",
      country: country ?? "United Kingdom",
      isoCountryCode: "",
    )
  }

  func createPhotokitAssetResource(
    assetResourceType: PhotokitAssetResourceType? = nil,
  ) -> PhotokitAssetResource {
    return PhotokitAssetResource(
      assetResourceType: assetResourceType ?? .photo,
      originalFileName: "IMG_\(Int.random(in: 0...99999)).png",
      fileSize: Int64.random(in: 1000...99999),
      pixelHeight: Int64.random(in: 100...5000),
      pixelWidth: Int64.random(in: 100...4000),
    )
  }

  func createPhotokitAsset(
    assetId: String? = nil,
    mediaType: PhotokitAssetMediaType? = nil,
    assetLibrary: AssetLibrary? = nil,
    createdAt: Date? = nil,
    updatedAt: Date? = nil,
    importedAt: Date? = nil,
    isFavourite: Bool? = nil,
    resources: [PhotokitAssetResource]? = nil,
  ) throws -> PhotokitAsset {
    let actualCreatedAt = createdAt ?? Date(
      timeIntervalSince1970: Double(Int.random(in: defaultDateStart...defaultDateEnd))
    )
    let randomUpdatedAt: Date? = if Bool.random() {
      Date(
        timeIntervalSince1970: actualCreatedAt.timeIntervalSince1970 + Double(Int.random(in: 3600...86400))
      )
    } else { nil }

    var randomResources = [PhotokitAssetResource]()
    for _ in 0...Int.random(in: 1...3) {
      randomResources.append(createPhotokitAssetResource())
    }

    return PhotokitAsset(
      id: assetId ?? UUID().uuidString,
      assetMediaType: mediaType ?? .image,
      assetLibrary: assetLibrary ?? .personalLibrary,
      createdAt: actualCreatedAt,
      updatedAt: updatedAt ?? randomUpdatedAt,
      isFavourite: isFavourite ?? Bool.random(),
      geoLat: Decimal(Double.random(in: -90...90)).rounded(scale: 6),
      geoLong: Decimal(Double.random(in: -180...180)).rounded(scale: 6),
      resources: resources ?? randomResources
    )
  }

  func createExportedAsset(
    photokitAsset: PhotokitAsset,
    aestheticScore: Int64,
    now: Date,
  ) -> ExportedAsset {
    return ExportedAsset.fromPhotokitAsset(
      asset: photokitAsset,
      aestheticScore: aestheticScore,
      now: now,
    )!
  }

  func createExportedAsset(
    assetType: AssetType? = nil,
    assetLibrary: AssetLibrary? = nil,
    createdAt: Date? = nil,
    updatedAt: Date? = nil,
    importedAt: Date? = nil,
    isFavourite: Bool? = nil,
    aestheticScore: Int64? = nil,
    isDeleted: Bool? = nil,
    deletedAt: Date? = nil,
  ) -> ExportedAsset {
    let actualCreatedAt = createdAt ?? Date(
      timeIntervalSince1970: Double(Int.random(in: defaultDateStart...defaultDateEnd))
    )
    let randomImportedAt = Date(
      timeIntervalSince1970: actualCreatedAt.timeIntervalSince1970 + Double(Int.random(in: 3600...86400))
    )
    let randomUpdatedAt: Date? = if Bool.random() {
      Date(
        timeIntervalSince1970: actualCreatedAt.timeIntervalSince1970 + Double(Int.random(in: 3600...86400))
      )
    } else { nil }

    return ExportedAsset(
      id: UUID().uuidString,
      assetType: assetType ?? AssetType.image,
      assetLibrary: assetLibrary ?? .personalLibrary,
      createdAt: actualCreatedAt,
      updatedAt: updatedAt ?? randomUpdatedAt,
      importedAt: importedAt ?? randomImportedAt,
      isFavourite: isFavourite ?? Bool.random(),
      aestheticScore: aestheticScore ?? Int64.random(in: 1000000...9999999),
      isDeleted: isDeleted ?? false,
      deletedAt: deletedAt
    )
  }

  func createAndSaveExportedAsset(
    photokitAsset: PhotokitAsset,
    aestheticScore: Int64,
    now: Date,
  ) throws -> ExportedAsset {
    let asset = ExportedAsset.fromPhotokitAsset(
      asset: photokitAsset,
      aestheticScore: aestheticScore,
      now: now,
    )!
    _ = try exporterDB.upsertAsset(asset: asset)
    return asset
  }

  func createAndSaveExportedAsset(
    assetType: AssetType? = nil,
    assetLibrary: AssetLibrary? = nil,
    createdAt: Date? = nil,
    updatedAt: Date? = nil,
    importedAt: Date? = nil,
    isFavourite: Bool? = nil,
    aestheticScore: Int64? = nil,
    isDeleted: Bool? = nil,
    deletedAt: Date? = nil,
  ) throws -> ExportedAsset {
    let asset = createExportedAsset(
      assetType: assetType,
      assetLibrary: assetLibrary,
      createdAt: createdAt,
      updatedAt: updatedAt,
      importedAt: importedAt,
      isFavourite: isFavourite,
      aestheticScore: aestheticScore,
      isDeleted: isDeleted,
      deletedAt: deletedAt,
    )
    _ = try exporterDB.upsertAsset(asset: asset)
    return asset
  }

  func createExportedFile(
    photokitAsset: PhotokitAsset,
    photokitResource: PhotokitAssetResource,
    now: Date,
    country: String?,
    city: String?,
    wasCopied: Bool? = nil,
  ) throws -> ExportedFile {
    let cityId: Int64? = if let city {
      try self.exporterDB.getLookupTableIdByName(
        table: .city, name: city
      )
    } else { nil }

    let countryId: Int64? = if let country {
      try self.exporterDB.getLookupTableIdByName(
        table: .country, name: country
      )
    } else { nil }

    return ExportedFile.fromPhotokitAssetResource(
      asset: photokitAsset,
      resource: photokitResource,
      now: now,
      countryId: countryId,
      cityId: cityId,
      country: country,
      city: city,
    )!.copy(wasCopied: wasCopied ?? false)
  }

  func createExportedFile(
    asset: ExportedAsset,
    fileType: FileType? = nil,
    originalFileName: String? = nil,
    fileSize: Int64? = nil,
    pixelHeight: Int64? = nil,
    pixelWidth: Int64? = nil,
    importedAt: Date? = nil,
    country: String? = nil,
    city: String? = nil,
    wasCopied: Bool? = nil,
  ) throws -> ExportedFile {
    let cityId: Int64? = if let city {
      try self.exporterDB.getLookupTableIdByName(
        table: .city, name: city
      )
    } else { nil }

    let countryId: Int64? = if let country {
      try self.exporterDB.getLookupTableIdByName(
        table: .country, name: country
      )
    } else { nil }

    let randomFileName = "IMG0\(Int.random(in: 1...99999)).jpg"
    let randomFileSize = fileSize ?? Int64.random(in: 1000000...99999999)
    return ExportedFile(
      id: ExportedFile.generateId(
        assetCreatedAt: asset.createdAt,
        fileSize: randomFileSize,
        fileType: fileType ?? FileType.originalImage,
        originalFileName: randomFileName,
      ),
      fileType: fileType ?? FileType.originalImage,
      originalFileName: originalFileName ?? randomFileName,
      geoLat: Decimal(Double.random(in: -90...90)).rounded(scale: 6),
      geoLong: Decimal(Double.random(in: -180...180)).rounded(scale: 6),
      countryId: countryId,
      cityId: cityId,
      fileSize: randomFileSize,
      pixelHeight: pixelHeight ?? Int64.random(in: 100...5000),
      pixelWidth: pixelWidth ?? Int64.random(in: 100...4000),
      importedAt: importedAt ?? TestHelpers.dateFromStr("2025-03-15 11:30:05")!,
      importedFileDir: FileHelper.pathForDateAndLocation(
        date: asset.createdAt,
        country: country,
        city: city
      ),
      wasCopied: wasCopied ?? false,
    )
  }

  func createAndSaveExportedFile(
    asset: ExportedAsset,
    fileType: FileType? = nil,
    originalFileName: String? = nil,
    fileSize: Int64? = nil,
    pixelHeight: Int64? = nil,
    pixelWidth: Int64? = nil,
    importedAt: Date? = nil,
    country: String? = nil,
    city: String? = nil,
    wasCopied: Bool? = nil,
  ) throws -> ExportedFile {
    let file = try createExportedFile(
      asset: asset,
      fileType: fileType,
      originalFileName: originalFileName,
      fileSize: fileSize,
      pixelHeight: pixelHeight,
      pixelWidth: pixelWidth,
      importedAt: importedAt,
      country: country,
      city: city,
      wasCopied: wasCopied,
    )
    _ = try exporterDB.upsertFile(file: file)
    return file
  }

  func createAndSaveExportedFile(
    photokitAsset: PhotokitAsset,
    photokitResource: PhotokitAssetResource,
    now: Date,
    country: String?,
    city: String?,
    wasCopied: Bool? = nil,
  ) throws -> ExportedFile {
    let cityId: Int64? = if let city {
      try self.exporterDB.getLookupTableIdByName(
        table: .city, name: city
      )
    } else { nil }

    let countryId: Int64? = if let country {
      try self.exporterDB.getLookupTableIdByName(
        table: .country, name: country
      )
    } else { nil }

    let file = ExportedFile.fromPhotokitAssetResource(
      asset: photokitAsset,
      resource: photokitResource,
      now: now,
      countryId: countryId,
      cityId: cityId,
      country: country,
      city: city,
    )!.copy(wasCopied: wasCopied ?? false)
    _ = try exporterDB.upsertFile(file: file)
    return file
  }

  func createAssetFile(
    assetId: String,
    fileId: String,
    isDeleted: Bool? = nil,
    deletedAt: Date? = nil,
  ) -> ExportedAssetFile {
    return ExportedAssetFile(
      assetId: assetId,
      fileId: fileId,
      isDeleted: isDeleted ?? false,
      deletedAt: deletedAt
    )
  }

  func createAndSaveAssetFile(
    assetId: String,
    fileId: String,
    isDeleted: Bool? = nil,
    deletedAt: Date? = nil,
  ) throws -> ExportedAssetFile {
    let assetFile = createAssetFile(
      assetId: assetId,
      fileId: fileId,
      isDeleted: isDeleted,
      deletedAt: deletedAt,
    )
    _ = try exporterDB.upsertAssetFile(assetFile: assetFile)
    return assetFile
  }

  func createAndSaveLinkedFile() throws -> (ExportedAsset, ExportedFile, ExportedAssetFile) {
    let asset = try createAndSaveExportedAsset()
    let file = try createAndSaveExportedFile(asset: asset)
    let assetFile = try createAndSaveAssetFile(assetId: asset.id, fileId: file.id)
    return (asset, file, assetFile)
  }

  func createPhotokitFolder(
    id: String? = nil,
    title: String? = nil,
    subfolders: [PhotokitFolder]? = nil,
    albums: [PhotokitAlbum]? = nil,
  ) -> PhotokitFolder {
    return PhotokitFolder(
      id: id ?? UUID().uuidString,
      title: title ?? "My Folder \(Int.random(in: 1...999999))",
      subfolders: subfolders ?? [],
      albums: albums ?? [],
    )
  }

  func createExportedFolder(
    name: String? = nil,
    parentId: String? = nil,
  ) -> ExportedFolder {
    return ExportedFolder(
      id: UUID().uuidString,
      name: name ?? "My Folder \(Int.random(in: 1...99))",
      parentId: parentId,
    )
  }

  func createAndSaveExportedFolder(
    name: String? = nil,
    parentId: String? = nil,
  ) throws -> ExportedFolder {
    let folder = createExportedFolder(
      name: name,
      parentId: parentId,
    )
    _ = try exporterDB.upsertFolder(folder: folder)
    return folder
  }

  func createPhotokitAlbum(
    id: String? = nil,
    title: String? = nil,
    collectionSubtype: PhotokitAssetCollectionSubType? = nil,
    assetIds: [String]? = nil,
  ) -> PhotokitAlbum {
    return PhotokitAlbum(
      id: id ?? UUID().uuidString,
      title: title ?? "My Album \(Int.random(in: 1...999999))",
      collectionSubtype: .albumRegular,
      assetIds: assetIds ?? [],
    )
  }

  func createExportedAlbum(
    albumFolderId: String,
    albumType: AlbumType? = nil,
    name: String? = nil,
    assetIds: Set<String>? = nil,
  ) -> ExportedAlbum {
    return ExportedAlbum(
      id: UUID().uuidString,
      albumType: albumType ?? .user,
      albumFolderId: albumFolderId,
      name: name ?? "My Album \(Int.random(in: 1...9999))",
      assetIds: assetIds ?? Set(),
    )
  }

  func createAndSaveExportedAlbum(
    albumFolderId: String,
    albumType: AlbumType? = nil,
    name: String? = nil,
    assetIds: Set<String>? = nil,
  ) throws -> ExportedAlbum {
    let album = createExportedAlbum(
      albumFolderId: albumFolderId,
      albumType: albumType,
      name: name,
      assetIds: assetIds,
    )
    _ = try exporterDB.upsertAlbum(album: album)
    return album
  }

  func createExportResult() -> PhotosExporterLib.Result {
    return PhotosExporterLib.Result(
      assetExport: AssetExporter.Result(
        assetInserted: Int.random(in: 0...9999),
        assetUpdated: Int.random(in: 0...9999),
        assetUnchanged: Int.random(in: 0...9999),
        assetSkipped: Int.random(in: 0...9999),
        assetMarkedForDeletion: Int.random(in: 0...9999),
        assetDeleted: Int.random(in: 0...9999),
        fileInserted: Int.random(in: 0...9999),
        fileUpdated: Int.random(in: 0...9999),
        fileUnchanged: Int.random(in: 0...9999),
        fileSkipped: Int.random(in: 0...9999),
        fileMarkedForDeletion: Int.random(in: 0...9999),
        fileDeleted: Int.random(in: 0...9999),
      ),
      collectionExport: CollectionExporter.Result(
        folderInserted: Int.random(in: 0...9999),
        folderUpdated: Int.random(in: 0...9999),
        folderUnchanged: Int.random(in: 0...9999),
        albumInserted: Int.random(in: 0...9999),
        albumUpdated: Int.random(in: 0...9999),
        albumUnchanged: Int.random(in: 0...9999),
      ),
      fileExport: FileExporter.Result(
        copied: Int.random(in: 0...9999),
        deleted: Int.random(in: 0...9999),
      )
    )
  }

  func createExportResultHistoryEntry(now: Date? = nil) -> ExportResultHistoryEntry {
    return ExportResultHistoryEntry(
      id: UUID().uuidString,
      createdAt: now ?? Date(
        timeIntervalSince1970: Double(Int.random(in: defaultDateStart...defaultDateEnd))
      ),
      exportResult: createExportResult(),
      assetCount: Int.random(in: 0...9999),
      fileCount: Int.random(in: 0...9999),
      albumCount: Int.random(in: 0...9999),
      folderCount: Int.random(in: 0...9999),
      fileSizeTotal: Int64.random(in: 10000...9999999),
      runTime: Decimal(Double.random(in: 10...200)),
    )
  }

  func createAndSaveExportResultHistoryEntry(now: Date? = nil) throws -> ExportResultHistoryEntry {
    let entry = createExportResultHistoryEntry()
    try exporterDB.insertExportResultHistoryEntry(entry: entry)
    return entry
  }
}
