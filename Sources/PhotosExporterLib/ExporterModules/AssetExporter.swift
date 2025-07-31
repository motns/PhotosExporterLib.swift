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
struct AssetExporter: Sendable {
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
    self.exporterDB = exporterDB
    self.photosDB = photosDB
    self.photokit = photokit
    self.countryLookup = CachedLookupTable(table: .country, exporterDB: exporterDB, logger: logger)
    self.cityLookup = CachedLookupTable(table: .city, exporterDB: exporterDB, logger: logger)
    self.logger = ClassLogger(className: "AssetExporter", logger: logger)
    self.timeProvider = timeProvider
    self.expiryDays = expiryDays
  }

  // swiftlint:disable:next function_body_length cyclomatic_complexity
  func export(isEnabled: Bool = true) -> AsyncThrowingStream<
    AssetExporterStatus,
    Swift.Error
  > {
    return AsyncThrowingStream(bufferingPolicy: .bufferingNewest(10)) { continuation in
      Task {
        var status = AssetExporterStatus.notStarted()
        let startTime = await timeProvider.getDate()

        guard isEnabled else {
          logger.warning("Asset export disabled - skipping")
          status = status.withMainStatus(.skipped)
          continuation.yield(status)
          continuation.finish()
          return
        }

        guard !Task.isCancelled else {
          logger.warning("Asset Exporter Task cancelled")
          status = status.withMainStatus(.cancelled)
          continuation.yield(status)
          continuation.finish()
          return
        }

        var assetExportResult = AssetExporterResult.empty()

        status = status.withMainStatus(.running(nil))
        continuation.yield(status)
        for try await exportAssetStatus in exportAssets() {
          switch exportAssetStatus {
          case .notStarted, .skipped, .cancelled: break
          case .running:
            status = status.withExportAssetStatus(exportAssetStatus)
            continuation.yield(status)
          case .failed(let error):
            status = status
              .withMainStatus(.failed(error))
              .withExportAssetStatus(exportAssetStatus)
            continuation.yield(status)
            continuation.finish(throwing: Error.unexpectedError("\(error)"))
            return
          case .complete(let result):
            assetExportResult = result
            status = status.withExportAssetStatus(exportAssetStatus)
            continuation.yield(status)
          }
        }

        guard !Task.isCancelled else {
          logger.warning("Asset Exporter Task cancelled")
          status = status.withMainStatus(.cancelled)
          continuation.yield(status)
          continuation.finish()
          return
        }

        var assetMarkedDeleteResult = AssetMarkedDeletedResult.empty()

        for try await markDeletedStatus in markDeletedAssetsAndFiles() {
          switch markDeletedStatus {
          case .notStarted, .skipped, .cancelled: break
          case .running:
            status = status.withMarkDeletedStatus(markDeletedStatus)
            continuation.yield(status)
          case .failed(let error):
            status = status
              .withMainStatus(.failed(error))
              .withMarkDeletedStatus(markDeletedStatus)
            continuation.yield(status)
            continuation.finish(throwing: Error.unexpectedError("\(error)"))
            return
          case .complete(let result):
            assetMarkedDeleteResult = result
            status = status.withMarkDeletedStatus(markDeletedStatus)
            continuation.yield(status)
          }
        }

        guard !Task.isCancelled else {
          logger.warning("Asset Exporter Task cancelled")
          status = status.withMainStatus(.cancelled)
          continuation.yield(status)
          continuation.finish()
          return
        }

        var removedExpiredAssetResult = RemoveExpiredAssetResult.empty()

        for try await removeExpiredStatus in removeExpiredAssetsAndFiles() {
          switch removeExpiredStatus {
          case .notStarted, .skipped, .cancelled: break
          case .running:
            status = status.withRemoveExpiredStatus(removeExpiredStatus)
            continuation.yield(status)
          case .failed(let error):
            status = status
              .withMainStatus(.failed(error))
              .withRemoveExpiredStatus(removeExpiredStatus)
            continuation.yield(status)
            continuation.finish(throwing: Error.unexpectedError("\(error)"))
            return
          case .complete(let result):
            removedExpiredAssetResult = result
            status = status.withRemoveExpiredStatus(removeExpiredStatus)
            continuation.yield(status)
          }
        }

        let runTime = await timeProvider.secondsPassedSince(startTime)
        logger.info("Asset export complete in \(runTime)s")

        status = status.withMainStatus(.complete(
          assetExportResult.copy(
            assetMarkedForDeletion: assetMarkedDeleteResult.assetMarkedCnt,
            assetDeleted: removedExpiredAssetResult.assetDeletedCnt,
            fileMarkedForDeletion: assetMarkedDeleteResult.fileMarkedCnt,
            fileDeleted: removedExpiredAssetResult.fileDeletedCnt,
            runTime: runTime,
          )
        ))
        continuation.yield(status)
        continuation.finish()
      }
    }
  }

  // swiftlint:disable:next function_body_length
  private func exportAssets() -> AsyncThrowingStream<
    TaskStatus<AssetExporterResult>,
    Swift.Error
  > {
    return AsyncThrowingStream { continuation in
      Task {
        var status: TaskStatus<AssetExporterResult> = .notStarted

        do {
          logger.info("Exporting Assets to local DB...")
          let startTime = await timeProvider.getDate()
          status = .running(nil)
          continuation.yield(status)

          guard !Task.isCancelled else {
            logger.info("Export Asset Task cancelled")
            continuation.yield(.cancelled)
            continuation.finish()
            return
          }

          let assetLocationById = try await photosDB.getAllAssetLocationsById()
          let assetScoreById = try await photosDB.getAllAssetScoresById()
          let allPhotokitAssetsResult = try await photokit.getAllAssetsResult()
          var assetResults = [ExporterDB.UpsertResult?]()
          var fileResults = [ExporterDB.UpsertResult?]()

          var progress = TaskProgress(toProcess: allPhotokitAssetsResult.count)
          status = .running(progress)
          continuation.yield(status)

          while let photokitAsset = try await allPhotokitAssetsResult.next() {
            guard !Task.isCancelled else {
              logger.info("Export Asset Task cancelled")
              continuation.yield(.cancelled)
              continuation.finish()
              return
            }

            let assetLocation = assetLocationById[photokitAsset.uuid]

            let (country, countryId): (String?, Int64?) = switch assetLocation?.country {
            case .none: (nil, nil)
            case .some(let country): (country, try await countryLookup.getIdByName(name: country))
            }

            let (city, cityId): (String?, Int64?) = switch assetLocation?.city {
            case .none: (nil, nil)
            case .some(let city): (city, try await cityLookup.getIdByName(name: city))
            }

            let exportedAssetOpt = ExportedAsset.fromPhotokitAsset(
              asset: photokitAsset,
              aestheticScore: assetScoreById[photokitAsset.uuid] ?? 0,
              now: await self.timeProvider.getDate()
            )
            guard let exportedAsset = exportedAssetOpt else {
              logger.warning(
                "Could not convert Photokit Asset to Exported Asset",
                ["asset_id": "\(photokitAsset.id)"]
              )
              assetResults.append(nil)
              continue
            }
            assetResults.append(try exporterDB.upsertAsset(asset: exportedAsset, now: await timeProvider.getDate()))

            for photokitResource in photokitAsset.resources {
              fileResults.append(try await processResource(
                asset: photokitAsset,
                resource: photokitResource,
                countryId: countryId,
                cityId: cityId,
                country: country,
                city: city,
              ))
            }
            progress = progress.processed()
            status = .running(progress)
            continuation.yield(status)
          }

          continuation.yield(.complete(
            sumUpsertResults(
              assetResults: assetResults,
              fileResults: fileResults,
              runTime: await timeProvider.secondsPassedSince(startTime)
            )
          ))
          continuation.finish()
        } catch {
          continuation.yield(.failed("\(error)"))
          continuation.finish(throwing: error)
        }
      }
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
  ) async throws -> ExporterDB.UpsertResult? {
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
      now: await timeProvider.getDate(),
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

  // swiftlint:disable:next function_body_length
  private func markDeletedAssetsAndFiles() -> AsyncThrowingStream<
    TaskStatus<AssetMarkedDeletedResult>,
    Swift.Error
  > {
    return AsyncThrowingStream { continuation in
      Task {
        do {
          logger.debug("Finding Asset and File IDs deleted from Photos...")
          let startTime = await timeProvider.getDate()
          continuation.yield(TaskStatus<AssetMarkedDeletedResult>.running(nil))

          guard !Task.isCancelled else {
            logger.info("Mark Deleted Assets Task cancelled")
            continuation.yield(.cancelled)
            continuation.finish()
            return
          }

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
              guard !Task.isCancelled else {
                logger.info("Mark Deleted Assets Task cancelled")
                continuation.yield(.cancelled)
                continuation.finish()
                return
              }

              try exporterDB.markAssetAsDeleted(id: assetId, now: await timeProvider.getDate())
            }
          }

          if exportedFileIds.isEmpty {
            logger.debug("No File IDs have been removed from Photos")
          } else {
            logger.debug("Found \(exportedFileIds.count) File IDs removed from Photos - updating DB...")
            for fileId in exportedFileIds {
              guard !Task.isCancelled else {
                logger.info("Mark Deleted Assets Task cancelled")
                continuation.yield(.cancelled)
                continuation.finish()
                return
              }

              try exporterDB.markFileAsDeleted(id: fileId, now: await timeProvider.getDate())
            }
          }

          continuation.yield(.complete(
            AssetMarkedDeletedResult(
              assetMarkedCnt: exportedAssetIds.count,
              fileMarkedCnt: exportedFileIds.count,
              runTime: await timeProvider.secondsPassedSince(startTime),
            )
          ))
          continuation.finish()
        } catch {
          continuation.yield(.failed("\(error)"))
          continuation.finish(throwing: error)
        }
      }
    }
  }

  private func removeExpiredAssetsAndFiles() -> AsyncThrowingStream<
    TaskStatus<RemoveExpiredAssetResult>,
    Swift.Error
  > {
    return AsyncThrowingStream { continuation in
      Task {
        do {
          continuation.yield(TaskStatus<RemoveExpiredAssetResult>.running(nil))
          let startTime = await timeProvider.getDate()
          let cutoffDate = await timeProvider.getDate().addingTimeInterval(Double(expiryDays * 3600 * 24 * -1))
          logger.debug("Removing Assets and AssetFiles marked as deleted before \(cutoffDate)...")
          let (assetsDeletedCnt, filesDeletedCnt1) = try exporterDB.deleteExpiredAssets(cutoffDate: cutoffDate)
          let filesDeletedCnt2 = try exporterDB.deleteExpiredAssetFiles(cutoffDate: cutoffDate)
          continuation.yield(.complete(
            RemoveExpiredAssetResult(
              assetDeletedCnt: assetsDeletedCnt,
              fileDeletedCnt: filesDeletedCnt1 + filesDeletedCnt2,
              runTime: await timeProvider.secondsPassedSince(startTime),
            )
          ))
          continuation.finish()
        } catch {
          continuation.yield(.failed("\(error)"))
          continuation.finish(throwing: error)
        }
      }
    }
  }

  // swiftlint:disable:next cyclomatic_complexity
  private func sumUpsertResults(
    assetResults: [ExporterDB.UpsertResult?],
    fileResults: [ExporterDB.UpsertResult?],
    runTime: Double,
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
      runTime: runTime,
    )
  }
}

public struct AssetExporterResult: Codable, Sendable, Timeable {
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
  public let runTime: Double

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
      runTime: 0,
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
    runTime: Double? = nil,
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
      runTime: runTime ?? self.runTime,
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
      .add(diffProperty(other, \.runTime))
  }
}

public struct AssetMarkedDeletedResult: Sendable, Timeable {
  public let assetMarkedCnt: Int
  public let fileMarkedCnt: Int
  public let runTime: Double

  static func empty() -> AssetMarkedDeletedResult {
    return AssetMarkedDeletedResult(
      assetMarkedCnt: 0,
      fileMarkedCnt: 0,
      runTime: 0,
    )
  }
}

public struct RemoveExpiredAssetResult: Sendable, Timeable {
  public let assetDeletedCnt: Int
  public let fileDeletedCnt: Int
  public let runTime: Double

  static func empty() -> RemoveExpiredAssetResult {
    return RemoveExpiredAssetResult(
      assetDeletedCnt: 0,
      fileDeletedCnt: 0,
      runTime: 0,
    )
  }
}

public struct AssetExporterStatus: Sendable {
  public let status: TaskStatus<AssetExporterResult>
  public let exportAssetStatus: TaskStatus<AssetExporterResult>
  public let markDeletedStatus: TaskStatus<AssetMarkedDeletedResult>
  public let removeExpiredStatus: TaskStatus<RemoveExpiredAssetResult>

  static func notStarted() -> AssetExporterStatus {
    return AssetExporterStatus(
      status: .notStarted,
      exportAssetStatus: .notStarted,
      markDeletedStatus: .notStarted,
      removeExpiredStatus: .notStarted,
    )
  }

  func copy(
    status: TaskStatus<AssetExporterResult>? = nil,
    exportAssetStatus: TaskStatus<AssetExporterResult>? = nil,
    markDeletedStatus: TaskStatus<AssetMarkedDeletedResult>? = nil,
    removeExpiredStatus: TaskStatus<RemoveExpiredAssetResult>? = nil,
  ) -> AssetExporterStatus {
    return AssetExporterStatus(
      status: status ?? self.status,
      exportAssetStatus: exportAssetStatus ?? self.exportAssetStatus,
      markDeletedStatus: markDeletedStatus ?? self.markDeletedStatus,
      removeExpiredStatus: removeExpiredStatus ?? self.removeExpiredStatus,
    )
  }

  func withMainStatus(_ newStatus: TaskStatus<AssetExporterResult>) -> AssetExporterStatus {
    return copy(
      status: newStatus,
    )
  }

  func withExportAssetStatus(_ newStatus: TaskStatus<AssetExporterResult>) -> AssetExporterStatus {
    return copy(
      exportAssetStatus: newStatus,
    )
  }

  func withMarkDeletedStatus(_ newStatus: TaskStatus<AssetMarkedDeletedResult>) -> AssetExporterStatus {
    return copy(
      markDeletedStatus: newStatus,
    )
  }

  func withRemoveExpiredStatus(_ newStatus: TaskStatus<RemoveExpiredAssetResult>) -> AssetExporterStatus {
    return copy(
      removeExpiredStatus: newStatus,
    )
  }
}
