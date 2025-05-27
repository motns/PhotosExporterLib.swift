import Foundation
@testable import PhotosExporterLib

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
      fileSize: Int64.random(in: 1000...99999)
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
    assetType: AssetType? = nil,
    assetLibrary: AssetLibrary? = nil,
    createdAt: Date? = nil,
    updatedAt: Date? = nil,
    importedAt: Date? = nil,
    isFavourite: Bool? = nil,
    city: String? = nil,
    country: String? = nil,
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
      isDeleted: false,
      deletedAt: nil
    )
  }

  func insertAsset() throws -> ExportedAsset {
    let asset = try createExportedAsset()
    _ = try exporterDB.upsertAsset(asset: asset)
    return asset
  }

  func createFile(asset: ExportedAsset, city: String? = nil, country: String? = nil) -> ExportedFile {
    return ExportedFile(
      id: UUID().uuidString,
      fileType: FileType.originalImage,
      originalFileName: "IMG004.jpg",
      fileSize: 1234567,
      importedAt: TestHelpers.dateFromStr("2025-03-15 11:30:05")!,
      importedFileDir: FileHelper.pathForDateAndLocation(
        dateOpt: asset.createdAt,
        countryOpt: country,
        cityOpt: city
      ),
      importedFileName: FileHelper.filenameWithDateAndEdited(
        originalFileName: "IMG004.jpg",
        dateOpt: asset.createdAt,
        isEdited: FileType.originalImage.isEdited()
      ),
      wasCopied: false
    )
  }

  func insertFile(asset: ExportedAsset) throws -> ExportedFile {
    let file = createFile(asset: asset)
    _ = try exporterDB.upsertFile(file: file)
    return file
  }

  func createAssetFile(asset: ExportedAsset, file: ExportedFile) -> ExportedAssetFile {
    return ExportedAssetFile(
      assetId: asset.id,
      fileId: file.id,
      isDeleted: false,
      deletedAt: nil
    )
  }

  func insertAssetFile(asset: ExportedAsset, file: ExportedFile) throws -> ExportedAssetFile {
    let assetFile = createAssetFile(asset: asset, file: file)
    _ = try exporterDB.upsertAssetFile(assetFile: assetFile)
    return assetFile
  }

  func insertLinkedFile() throws -> (ExportedAsset, ExportedFile, ExportedAssetFile) {
    let asset = try insertAsset()
    let file = try insertFile(asset: asset)
    let assetFile = try insertAssetFile(asset: asset, file: file)
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
}
