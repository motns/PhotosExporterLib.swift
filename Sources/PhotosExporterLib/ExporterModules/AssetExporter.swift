import Logging

struct AssetExporter {
  private var exporterDB: ExporterDB
  private var photosDB: PhotosDBProtocol
  private let countryLookup: CachedLookupTable
  private let cityLookup: CachedLookupTable
  private var photokit: PhotokitProtocol
  private var logger: ClassLogger
  private var timeProvider: TimeProvider

  init(
    exporterDB: ExporterDB,
    photosDB: PhotosDBProtocol,
    photokit: PhotokitProtocol,
    logger: Logger,
    timeProvider: TimeProvider,
    isEnabled: Bool = true,
  ) {
    self.exporterDB = exporterDB
    self.photosDB = photosDB
    self.photokit = photokit
    self.countryLookup = CachedLookupTable(table: .country, exporterDB: exporterDB, logger: logger)
    self.cityLookup = CachedLookupTable(table: .city, exporterDB: exporterDB, logger: logger)
    self.logger = ClassLogger(logger: logger, className: "AssetExporter")
    self.timeProvider = timeProvider
  }

  func export(isEnabled: Bool = true) async throws -> AssetExportResult {
    guard isEnabled else {
      logger.warning("Asset export disabled - skipping")
      return AssetExportResult.empty()
    }
    logger.info("Exporting Assets to local DB...")
    let startDate = timeProvider.getDate()

    let assetLocationById = try photosDB.getAllAssetLocationsById()
    let allPhotokitAssets = try await photokit.getAllAssets()
    var assetResults = [UpsertResult?]()
    var fileResults = [UpsertResult?]()

    for photokitAsset in allPhotokitAssets {
      let assetLocationOpt = assetLocationById[photokitAsset.uuid]

      let (countryOpt, countryIdOpt): (String?, Int64?) = switch assetLocationOpt?.country {
      case .none: (nil, nil)
      case .some(let country): (country, try countryLookup.getIdByName(name: country))
      }

      let (cityOpt, cityIdOpt): (String?, Int64?) = switch assetLocationOpt?.city {
      case .none: (nil, nil)
      case .some(let city): (city, try cityLookup.getIdByName(name: city))
      }

      let exportedAssetOpt = ExportedAsset.fromPhotokitAsset(
        asset: photokitAsset,
        cityId: cityIdOpt,
        countryId: countryIdOpt,
        now: self.timeProvider.getDate()
      )
      guard let exportedAsset = exportedAssetOpt else {
        logger.warning(
          "Could not convert Photokit Asset to Exported Asset",
          ["asset_id": "\(photokitAsset.id)"]
        )
        assetResults.append(nil)
        continue
      }
      assetResults.append(try exporterDB.upsertAsset(asset: exportedAsset, now: timeProvider.getDate()))

      for photokitResource in photokitAsset.resources {
        fileResults.append(try processResource(
          asset: photokitAsset,
          resource: photokitResource,
          countryOpt: countryOpt,
          cityOpt: cityOpt
        ))
      }
    }

    logger.info("Asset export complete in \(timeProvider.secondsPassedSince(startDate))s")
    return sumResults(assetResults: assetResults, fileResults: fileResults)
  }

  private func processResource(
    asset: PhotokitAsset,
    resource: PhotokitAssetResource,
    countryOpt: String?,
    cityOpt: String?,
  ) throws -> UpsertResult? {
    // Filter out supplementary files like adjustment data
    guard FileType.fromPhotokitAssetResourceType(resource.assetResourceType) != nil else {
      logger.trace(
        "Unsupported file type for Asset Resource",
        [
          "asset_id": "\(asset.id)",
          "resource_type": "\(resource.assetResourceType)",
          "original_file_name": "\(resource.originalFileName)",
        ]
      )
      return nil
    }

    let exportedFileOpt = ExportedFile.fromPhotokitAssetResource(
      asset: asset,
      resource: resource,
      countryOpt: countryOpt,
      cityOpt: cityOpt,
      now: timeProvider.getDate()
    )

    guard let exportedFile = exportedFileOpt else {
      logger.warning(
        "Could not convert Photokit Asset Resource to Exported File",
        [
          "asset_id": "\(asset.id)",
          "resource_type": "\(resource.assetResourceType)",
          "original_file_name": "\(resource.originalFileName)",
        ]
      )
      return nil
    }

    let fileResult = try exporterDB.upsertFile(file: exportedFile)

    let assetFile = ExportedAssetFile(
      assetId: asset.id,
      fileId: exportedFile.id,
      isDeleted: false, // Implicitly false, since we have the Resource right here
      deletedAt: nil,
    )
    let assetFileResult = try exporterDB.upsertAssetFile(assetFile: assetFile)

    return fileResult.merge(assetFileResult)
  }

  // swiftlint:disable:next cyclomatic_complexity
  private func sumResults(
    assetResults: [UpsertResult?],
    fileResults: [UpsertResult?],
  ) -> AssetExportResult {
    var assetInsertCnt = 0
    var assetUpdateCnt = 0
    var assetUnchangedCnt = 0
    var assetSkippedCnt = 0

    for assetResult in assetResults {
      switch assetResult {
      case .none: assetSkippedCnt += 1
      case .some(let upsertResult):
        switch upsertResult {
        case .insert: assetInsertCnt += 1
        case .update: assetUpdateCnt += 1
        case .nochange: assetUnchangedCnt += 1
        }
      }
    }

    var fileInsertCnt = 0
    var fileUpdateCnt = 0
    var fileUnchangedCnt = 0
    var fileSkippedCnt = 0

    for fileResult in fileResults {
      switch fileResult {
      case .none: fileSkippedCnt += 1
      case .some(let upsertResult):
        switch upsertResult {
        case .insert: fileInsertCnt += 1
        case .update: fileUpdateCnt += 1
        case .nochange: fileUnchangedCnt += 1
        }
      }
    }

    return AssetExportResult(
      assetInserted: assetInsertCnt,
      assetUpdated: assetUpdateCnt,
      assetUnchanged: assetUnchangedCnt,
      assetSkipped: assetSkippedCnt,
      fileInserted: fileInsertCnt,
      fileUpdated: fileUpdateCnt,
      fileUnchanged: fileUnchangedCnt,
      fileSkipped: fileSkippedCnt,
    )
  }
}

public struct AssetExportResult: Sendable, Equatable {
  let assetInserted: Int
  let assetUpdated: Int
  let assetUnchanged: Int
  let assetSkipped: Int
  let fileInserted: Int
  let fileUpdated: Int
  let fileUnchanged: Int
  let fileSkipped: Int

  static func empty() -> AssetExportResult {
    return AssetExportResult(
      assetInserted: 0,
      assetUpdated: 0,
      assetUnchanged: 0,
      assetSkipped: 0,
      fileInserted: 0,
      fileUpdated: 0,
      fileUnchanged: 0,
      fileSkipped: 0
    )
  }
}
