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

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
struct AssetExporter {
  public let runStatus: AssetExporterStatus

  private var exporterDB: ExporterDB
  private var photosDB: PhotosDBProtocol
  private let countryLookup: CachedLookupTable
  private let cityLookup: CachedLookupTable
  private var photokit: PhotokitProtocol
  private var logger: ClassLogger
  private var timeProvider: TimeProvider
  private let expiryDays: Int

  public enum Error: Swift.Error {
    case unexpectedError(String)
  }

  init(
    exporterDB: ExporterDB,
    photosDB: PhotosDBProtocol,
    photokit: PhotokitProtocol,
    logger: Logger,
    timeProvider: TimeProvider,
    expiryDays: Int = 30,
  ) {
    self.runStatus = AssetExporterStatus()
    self.exporterDB = exporterDB
    self.photosDB = photosDB
    self.photokit = photokit
    self.countryLookup = CachedLookupTable(table: .country, exporterDB: exporterDB, logger: logger)
    self.cityLookup = CachedLookupTable(table: .city, exporterDB: exporterDB, logger: logger)
    self.logger = ClassLogger(className: "AssetExporter", logger: logger)
    self.timeProvider = timeProvider
    self.expiryDays = expiryDays
  }

  func export(isEnabled: Bool = true) async throws -> AssetExporterResult {
    guard isEnabled else {
      logger.warning("Asset export disabled - skipping")
      runStatus.skipped()
      return AssetExporterResult.empty()
    }

    do {
      runStatus.start()
      let startDate = timeProvider.getDate()
      let assetExportResult = try await exportAssets()
      let (assetMarkedCnt, fileMarkedCnt) = try await markDeletedAssetsAndFiles()
      let (assetDeletedCnt, fileDeletedCnt) = try removeExpiredAssetsAndFiles()

      let runTime = timeProvider.secondsPassedSince(startDate)
      logger.info("Asset export complete in \(runTime)s")
      runStatus.complete(runTime: runTime)
      return assetExportResult.copy(
        assetMarkedForDeletion: assetMarkedCnt,
        assetDeleted: assetDeletedCnt,
        fileMarkedForDeletion: fileMarkedCnt,
        fileDeleted: fileDeletedCnt,
      )
    } catch {
      runStatus.failed(error: "\(error)")
      throw Error.unexpectedError("\(error)")
    }
  }

  // swiftlint:disable:next function_body_length
  private func exportAssets() async throws -> AssetExporterResult {
    do {
      logger.info("Exporting Assets to local DB...")
      let startTime = timeProvider.getDate()
      runStatus.exportAssetStatus.start()

      let assetLocationById = try photosDB.getAllAssetLocationsById()
      let assetScoreById = try photosDB.getAllAssetScoresById()
      let allPhotokitAssetsResult = try await photokit.getAllAssetsResult()
      var assetResults = [ExporterDB.UpsertResult?]()
      var fileResults = [ExporterDB.UpsertResult?]()

      runStatus.exportAssetStatus.startProgress(toProcess: allPhotokitAssetsResult.count)

      while let photokitAsset = try await allPhotokitAssetsResult.next() {
        let assetLocation = assetLocationById[photokitAsset.uuid]

        let (country, countryId): (String?, Int64?) = switch assetLocation?.country {
        case .none: (nil, nil)
        case .some(let country): (country, try countryLookup.getIdByName(name: country))
        }

        let (city, cityId): (String?, Int64?) = switch assetLocation?.city {
        case .none: (nil, nil)
        case .some(let city): (city, try cityLookup.getIdByName(name: city))
        }

        let exportedAssetOpt = ExportedAsset.fromPhotokitAsset(
          asset: photokitAsset,
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
            countryId: countryId,
            cityId: cityId,
            country: country,
            city: city,
          ))
        }
        runStatus.exportAssetStatus.processed()
      }

      runStatus.exportAssetStatus.complete(runTime: timeProvider.secondsPassedSince(startTime))
      return sumUpsertResults(assetResults: assetResults, fileResults: fileResults)
    } catch {
      runStatus.exportAssetStatus.failed(error: "\(error)")
      throw error // Will be caught in main method above
    }
  }

  // swiftlint:disable:next function_parameter_count
  private func processResource(
    asset: PhotokitAsset,
    resource: PhotokitAssetResource,
    countryId: Int64?,
    cityId: Int64?,
    country: String?,
    city: String?,
  ) throws -> ExporterDB.UpsertResult? {
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
      now: timeProvider.getDate(),
      countryId: countryId,
      cityId: cityId,
      country: country,
      city: city,
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
    do {
      logger.debug("Finding Asset and File IDs deleted from Photos...")
      let startTime = timeProvider.getDate()
      runStatus.markDeletedStatus.start()

      var exportedAssetIds = try exporterDB.getAssetIdSet()
      var exportedFileIds = try exporterDB.getFileIdSet()
      let allPhotokitAssetsResult = try await photokit.getAllAssetsResult()

      while let asset = try await allPhotokitAssetsResult.next() {
        exportedAssetIds.remove(asset.id)

        for resource in asset.resources {
          let id = ExportedFile.generateId(
            asset: asset,
            resource: resource
          )
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

      runStatus.markDeletedStatus.complete(runTime: timeProvider.secondsPassedSince(startTime))
      return (exportedAssetIds.count, exportedFileIds.count)
    } catch {
      runStatus.markDeletedStatus.failed(error: "\(error)")
      throw error // Will be caught in main method above
    }
  }

  private func removeExpiredAssetsAndFiles() throws -> (Int, Int) {
    do {
      runStatus.removeExpiredStatus.start()
      let startTime = timeProvider.getDate()
      let cutoffDate = timeProvider.getDate().addingTimeInterval(Double(expiryDays * 3600 * 24 * -1))
      logger.debug("Removing Assets and AssetFiles marked as deleted before \(cutoffDate)...")
      let (assetsDeletedCnt, filesDeletedCnt1) = try exporterDB.deleteExpiredAssets(cutoffDate: cutoffDate)
      let filesDeletedCnt2 = try exporterDB.deleteExpiredAssetFiles(cutoffDate: cutoffDate)
      runStatus.removeExpiredStatus.complete(runTime: timeProvider.secondsPassedSince(startTime))
      return (assetsDeletedCnt, filesDeletedCnt1 + filesDeletedCnt2)
    } catch {
      runStatus.removeExpiredStatus.failed(error: "\(error)")
      throw error
    }
  }

  // swiftlint:disable:next cyclomatic_complexity
  private func sumUpsertResults(
    assetResults: [ExporterDB.UpsertResult?],
    fileResults: [ExporterDB.UpsertResult?],
  ) -> AssetExporterResult {
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

    return AssetExporterResult(
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

public struct AssetExporterResult: Codable, Sendable {
  public let assetInserted: Int
  public let assetUpdated: Int
  public let assetUnchanged: Int
  public let assetSkipped: Int
  public let assetMarkedForDeletion: Int
  public let assetDeleted: Int
  public let fileInserted: Int
  public let fileUpdated: Int
  public let fileUnchanged: Int
  public let fileSkipped: Int
  public let fileMarkedForDeletion: Int
  public let fileDeleted: Int

  public static func empty() -> AssetExporterResult {
    return AssetExporterResult(
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

  public func copy(
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
  ) -> AssetExporterResult {
    return AssetExporterResult(
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

extension AssetExporterResult: DiffableStruct {
  func getStructDiff(_ other: AssetExporterResult) -> StructDiff {
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

@Observable
public class AssetExporterStatus: PhotosExporterLib.RunStatus {
  public let exportAssetStatus: PhotosExporterLib.RunStatusWithProgress
  public let markDeletedStatus: PhotosExporterLib.RunStatus
  public let removeExpiredStatus: PhotosExporterLib.RunStatus

  public init(
    exportAssetStatus: PhotosExporterLib.RunStatusWithProgress? = nil,
    markDeletedStatus: PhotosExporterLib.RunStatus? = nil,
    removeExpiredStatus: PhotosExporterLib.RunStatus? = nil,
  ) {
    self.exportAssetStatus = exportAssetStatus ?? PhotosExporterLib.RunStatusWithProgress()
    self.markDeletedStatus = markDeletedStatus ?? PhotosExporterLib.RunStatus()
    self.removeExpiredStatus = removeExpiredStatus ?? PhotosExporterLib.RunStatus()
    super.init()
  }
}
