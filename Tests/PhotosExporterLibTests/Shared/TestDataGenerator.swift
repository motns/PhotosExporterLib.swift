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
  ) -> PostalAddress {
    return PostalAddress(
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
      geoLat: Double.random(in: -90...90),
      geoLong: Double.random(in: -180...180),
      resources: resources ?? randomResources
    )
  }

  func createExportedAsset(
    photokitAsset: PhotokitAsset,
    cityId: Int64?,
    countryId: Int64?,
    aestheticScore: Int64,
    now: Date,
  ) -> ExportedAsset {
    return ExportedAsset.fromPhotokitAsset(
      asset: photokitAsset,
      cityId: cityId,
      countryId: countryId,
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
    city: String? = nil,
    country: String? = nil,
    aestheticScore: Int64? = nil,
    isDeleted: Bool? = nil,
    deletedAt: Date? = nil,
  ) throws -> ExportedAsset {
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
      geoLat: Double.random(in: -90...90),
      geoLong: Double.random(in: -180...180),
      cityId: cityId,
      countryId: countryId,
      aestheticScore: aestheticScore ?? Int64.random(in: 1000000...9999999),
      isDeleted: isDeleted ?? false,
      deletedAt: deletedAt
    )
  }

  func createAndSaveExportedAsset(
    photokitAsset: PhotokitAsset,
    cityId: Int64?,
    countryId: Int64?,
    aestheticScore: Int64,
    now: Date,
  ) throws -> ExportedAsset {
    let asset = ExportedAsset.fromPhotokitAsset(
      asset: photokitAsset,
      cityId: cityId,
      countryId: countryId,
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
    city: String? = nil,
    country: String? = nil,
    aestheticScore: Int64? = nil,
    isDeleted: Bool? = nil,
    deletedAt: Date? = nil,
  ) throws -> ExportedAsset {
    let asset = try createExportedAsset(
      assetType: assetType,
      assetLibrary: assetLibrary,
      createdAt: createdAt,
      updatedAt: updatedAt,
      importedAt: importedAt,
      isFavourite: isFavourite,
      city: city,
      country: country,
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
    countryOpt: String?,
    cityOpt: String?,
    now: Date?,
    wasCopied: Bool? = nil,
  ) -> ExportedFile {
    return ExportedFile.fromPhotokitAssetResource(
      asset: photokitAsset,
      resource: photokitResource,
      countryOpt: countryOpt,
      cityOpt: cityOpt,
      now: now,
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
    city: String? = nil,
    country: String? = nil,
    wasCopied: Bool? = nil,
  ) -> ExportedFile {
    let randomFileName = "IMG0\(Int.random(in: 1...99999)).jpg"
    return ExportedFile(
      id: UUID().uuidString,
      fileType: fileType ?? FileType.originalImage,
      originalFileName: originalFileName ?? randomFileName,
      fileSize: fileSize ?? Int64.random(in: 1000000...99999999),
      pixelHeight: pixelHeight ?? Int64.random(in: 100...5000),
      pixelWidth: pixelWidth ?? Int64.random(in: 100...4000),
      importedAt: importedAt ?? TestHelpers.dateFromStr("2025-03-15 11:30:05")!,
      importedFileDir: FileHelper.pathForDateAndLocation(
        dateOpt: asset.createdAt,
        countryOpt: country,
        cityOpt: city
      ),
      importedFileName: FileHelper.filenameWithDateAndEdited(
        originalFileName: randomFileName,
        dateOpt: asset.createdAt,
        isEdited: FileType.originalImage.isEdited()
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
    city: String? = nil,
    country: String? = nil,
    wasCopied: Bool? = nil,
  ) throws -> ExportedFile {
    let file = createExportedFile(
      asset: asset,
      fileType: fileType,
      originalFileName: originalFileName,
      fileSize: fileSize,
      pixelHeight: pixelHeight,
      pixelWidth: pixelWidth,
      importedAt: importedAt,
      city: city,
      country: country,
      wasCopied: wasCopied,
    )
    _ = try exporterDB.upsertFile(file: file)
    return file
  }

  func createAndSaveExportedFile(
    photokitAsset: PhotokitAsset,
    photokitResource: PhotokitAssetResource,
    countryOpt: String?,
    cityOpt: String?,
    now: Date?,
    wasCopied: Bool? = nil,
  ) throws -> ExportedFile {
    let file = ExportedFile.fromPhotokitAssetResource(
      asset: photokitAsset,
      resource: photokitResource,
      countryOpt: countryOpt,
      cityOpt: cityOpt,
      now: now,
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

  func createExportResult() -> ExportResult {
    return ExportResult(
      assetExport: AssetExportResult(
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
      collectionExport: CollectionExportResult(
        folderInserted: Int.random(in: 0...9999),
        folderUpdated: Int.random(in: 0...9999),
        folderUnchanged: Int.random(in: 0...9999),
        albumInserted: Int.random(in: 0...9999),
        albumUpdated: Int.random(in: 0...9999),
        albumUnchanged: Int.random(in: 0...9999),
      ),
      fileExport: FileExportResult(
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
    )
  }

  func createAndSaveExportResultHistoryEntry(now: Date? = nil) throws -> ExportResultHistoryEntry {
    let entry = createExportResultHistoryEntry()
    try exporterDB.insertExportResultHistoryEntry(entry: entry)
    return entry
  }
}
