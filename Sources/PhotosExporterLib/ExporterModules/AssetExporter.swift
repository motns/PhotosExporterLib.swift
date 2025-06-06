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
import Logging

struct AssetExporter {
  private var exporterDB: ExporterDB
  private var photosDB: PhotosDBProtocol
  private let countryLookup: CachedLookupTable
  private let cityLookup: CachedLookupTable
  private var photokit: PhotokitProtocol
  private var logger: ClassLogger
  private var timeProvider: TimeProvider
  private let expiryDays: Int

  init(
    exporterDB: ExporterDB,
    photosDB: PhotosDBProtocol,
    photokit: PhotokitProtocol,
    logger: Logger,
    timeProvider: TimeProvider,
    expiryDays: Int = 30,
  ) {
    self.exporterDB = exporterDB
    self.photosDB = photosDB
    self.photokit = photokit
    self.countryLookup = CachedLookupTable(table: .country, exporterDB: exporterDB, logger: logger)
    self.cityLookup = CachedLookupTable(table: .city, exporterDB: exporterDB, logger: logger)
    self.logger = ClassLogger(logger: logger, className: "AssetExporter")
    self.timeProvider = timeProvider
    self.expiryDays = expiryDays
  }

  func export(isEnabled: Bool = true) async throws -> AssetExportResult {
    guard isEnabled else {
      logger.warning("Asset export disabled - skipping")
      return AssetExportResult.empty()
    }
    let startDate = timeProvider.getDate()
    let assetExportResult = try await exportAssets()
    let (assetMarkedCnt, fileMarkedCnt) = try await markDeletedAssetsAndFiles()
    let (assetDeletedCnt, fileDeletedCnt) = try removeExpiredAssetsAndFiles()
    logger.info("Asset export complete in \(timeProvider.secondsPassedSince(startDate))s")
    return assetExportResult.copy(
      assetMarkedForDeletion: assetMarkedCnt,
      assetDeleted: assetDeletedCnt,
      fileMarkedForDeletion: fileMarkedCnt,
      fileDeleted: fileDeletedCnt,
    )
  }

  private func exportAssets() async throws -> AssetExportResult {
    logger.info("Exporting Assets to local DB...")

    let assetLocationById = try photosDB.getAllAssetLocationsById()
    let assetScoreById = try photosDB.getAllAssetScoresById()
    let allPhotokitAssetsResult = try await photokit.getAllAssetsResult()
    var assetResults = [UpsertResult?]()
    var fileResults = [UpsertResult?]()

    while let photokitAsset = try await allPhotokitAssetsResult.next() {
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
        aestheticScore: assetScoreById[photokitAsset.uuid] ?? 0,
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

    return sumUpsertResults(assetResults: assetResults, fileResults: fileResults)
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

  private func markDeletedAssetsAndFiles() async throws -> (Int, Int) {
    logger.debug("Finding Asset and File IDs deleted from Photos...")
    var exportedAssetIds = try exporterDB.getAssetIdSet()
    var exportedFileIds = try exporterDB.getFileIdSet()
    let allPhotokitAssetsResult = try await photokit.getAllAssetsResult()

    while let asset = try await allPhotokitAssetsResult.next() {
      exportedAssetIds.remove(asset.id)

      for resource in asset.resources {
        let id = ExportedFile.generateId(asset: asset, resource: resource)
        exportedFileIds.remove(id)
      }
    }

    if exportedAssetIds.isEmpty {
      logger.debug("No Asset IDs have been removed from Photos")
    } else {
      logger.debug("Found \(exportedAssetIds.count) Asset IDs removed from Photos - updating DB...")
      for assetId in exportedAssetIds {
        try exporterDB.markAssetAsDeleted(id: assetId, now: timeProvider.getDate())
      }
    }

    if exportedFileIds.isEmpty {
      logger.debug("No File IDs have been removed from Photos")
    } else {
      logger.debug("Found \(exportedFileIds.count) File IDs removed from Photos - updating DB...")
      for fileId in exportedFileIds {
        try exporterDB.markFileAsDeleted(id: fileId, now: timeProvider.getDate())
      }
    }

    return (exportedAssetIds.count, exportedFileIds.count)
  }

  private func removeExpiredAssetsAndFiles() throws -> (Int, Int) {
    let cutoffDate = timeProvider.getDate().addingTimeInterval(Double(expiryDays * 3600 * 24 * -1))
    logger.debug("Removing Assets and AssetFiles marked as deleted before \(cutoffDate)...")
    let (assetsDeletedCnt, filesDeletedCnt1) = try exporterDB.deleteExpiredAssets(cutoffDate: cutoffDate)
    let filesDeletedCnt2 = try exporterDB.deleteExpiredAssetFiles(cutoffDate: cutoffDate)
    return (assetsDeletedCnt, filesDeletedCnt1 + filesDeletedCnt2)
  }

  // swiftlint:disable:next cyclomatic_complexity
  private func sumUpsertResults(
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
      assetMarkedForDeletion: 0,
      assetDeleted: 0,
      fileInserted: fileInsertCnt,
      fileUpdated: fileUpdateCnt,
      fileUnchanged: fileUnchangedCnt,
      fileSkipped: fileSkippedCnt,
      fileMarkedForDeletion: 0,
      fileDeleted: 0,
    )
  }
}

public struct AssetExportResult: Codable, Sendable {
  let assetInserted: Int
  let assetUpdated: Int
  let assetUnchanged: Int
  let assetSkipped: Int
  let assetMarkedForDeletion: Int
  let assetDeleted: Int
  let fileInserted: Int
  let fileUpdated: Int
  let fileUnchanged: Int
  let fileSkipped: Int
  let fileMarkedForDeletion: Int
  let fileDeleted: Int

  static func empty() -> AssetExportResult {
    return AssetExportResult(
      assetInserted: 0,
      assetUpdated: 0,
      assetUnchanged: 0,
      assetSkipped: 0,
      assetMarkedForDeletion: 0,
      assetDeleted: 0,
      fileInserted: 0,
      fileUpdated: 0,
      fileUnchanged: 0,
      fileSkipped: 0,
      fileMarkedForDeletion: 0,
      fileDeleted: 0,
    )
  }

  func copy(
    assetInserted: Int? = nil,
    assetUpdated: Int? = nil,
    assetUnchanged: Int? = nil,
    assetSkipped: Int? = nil,
    assetMarkedForDeletion: Int? = nil,
    assetDeleted: Int? = nil,
    fileInserted: Int? = nil,
    fileUpdated: Int? = nil,
    fileUnchanged: Int? = nil,
    fileSkipped: Int? = nil,
    fileMarkedForDeletion: Int? = nil,
    fileDeleted: Int? = nil,
  ) -> AssetExportResult {
    return AssetExportResult(
      assetInserted: assetInserted ?? self.assetInserted,
      assetUpdated: assetUpdated ?? self.assetUpdated,
      assetUnchanged: assetUnchanged ?? self.assetUnchanged,
      assetSkipped: assetSkipped ?? self.assetSkipped,
      assetMarkedForDeletion: assetMarkedForDeletion ?? self.assetMarkedForDeletion,
      assetDeleted: assetDeleted ?? self.assetDeleted,
      fileInserted: fileInserted ?? self.fileInserted,
      fileUpdated: fileUpdated ?? self.fileUpdated,
      fileUnchanged: fileUnchanged ?? self.fileUnchanged,
      fileSkipped: fileSkipped ?? self.fileSkipped,
      fileMarkedForDeletion: fileMarkedForDeletion ?? self.fileMarkedForDeletion,
      fileDeleted: fileDeleted ?? self.fileDeleted,
    )
  }
}

extension AssetExportResult: DiffableStruct {
  func getStructDiff(_ other: AssetExportResult) -> StructDiff {
    return StructDiff()
      .add(diffProperty(other, \.assetInserted))
      .add(diffProperty(other, \.assetUpdated))
      .add(diffProperty(other, \.assetUnchanged))
      .add(diffProperty(other, \.assetSkipped))
      .add(diffProperty(other, \.assetMarkedForDeletion))
      .add(diffProperty(other, \.assetDeleted))
      .add(diffProperty(other, \.fileInserted))
      .add(diffProperty(other, \.fileUpdated))
      .add(diffProperty(other, \.fileUnchanged))
      .add(diffProperty(other, \.fileSkipped))
      .add(diffProperty(other, \.fileMarkedForDeletion))
      .add(diffProperty(other, \.fileDeleted))
  }
}
