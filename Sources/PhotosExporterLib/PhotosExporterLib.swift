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
import Photos
import Logging

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
public struct PhotosExporterLib: Sendable {
  public let exportBaseDir: URL

  private let photokit: PhotokitProtocol
  private let exporterDB: ExporterDB
  private let fileManager: ExporterFileManagerProtocol
  private let logger: ClassLogger
  private let timeProvider: TimeProvider

  private let assetExporter: AssetExporter
  private let collectionExporter: CollectionExporter
  private let fileExporter: FileExporter
  private let symlinkCreator: SymlinkCreator

  public struct Result: Codable, Sendable, Equatable, Timeable {
    public let assetExport: AssetExporterResult
    public let collectionExport: CollectionExporterResult
    public let fileExport: FileExporterResult
    public let runTime: Double

    public static func empty() -> Result {
      return Result(
        assetExport: AssetExporterResult.empty(),
        collectionExport: CollectionExporterResult.empty(),
        fileExport: FileExporterResult.empty(),
        runTime: 0,
      )
    }
  }

  public enum Error: Swift.Error {
    case picturesDirectoryNotFound
    case photosLibraryNotFound(String)
    case missingPhotosDBFile(String)
    case unexpectedError(String)
  }

  public struct Status: Sendable {
    public let status: TaskStatus<Result>
    public let assetExporterStatus: AssetExporterStatus
    public let collectionExporterStatus: TaskStatus<CollectionExporterResult>
    public let fileExporterStatus: FileExporterStatus
    public let symlinkCreatorStatus: TaskStatus<EmptyTaskSuccess>

    public init(
      status: TaskStatus<Result>,
      assetExporterStatus: AssetExporterStatus,
      collectionExporterStatus: TaskStatus<CollectionExporterResult>,
      fileExporterStatus: FileExporterStatus,
      symlinkCreatorStatus: TaskStatus<EmptyTaskSuccess>,
    ) {
      self.status = status
      self.assetExporterStatus = assetExporterStatus
      self.collectionExporterStatus = collectionExporterStatus
      self.fileExporterStatus = fileExporterStatus
      self.symlinkCreatorStatus = symlinkCreatorStatus
    }

    public static func notStarted() -> Status {
      return Status(
        status: .notStarted,
        assetExporterStatus: AssetExporterStatus.notStarted(),
        collectionExporterStatus: .notStarted,
        fileExporterStatus: FileExporterStatus.notStarted(),
        symlinkCreatorStatus: .notStarted
      )
    }

    func copy(
      status: TaskStatus<Result>? = nil,
      assetExporterStatus: AssetExporterStatus? = nil,
      collectionExporterStatus: TaskStatus<CollectionExporterResult>? = nil,
      fileExporterStatus: FileExporterStatus? = nil,
      symlinkCreatorStatus: TaskStatus<EmptyTaskSuccess>? = nil,
    ) -> Status {
      return Status(
        status: status ?? self.status,
        assetExporterStatus: assetExporterStatus ?? self.assetExporterStatus,
        collectionExporterStatus: collectionExporterStatus ?? self.collectionExporterStatus,
        fileExporterStatus: fileExporterStatus ?? self.fileExporterStatus,
        symlinkCreatorStatus: symlinkCreatorStatus ?? self.symlinkCreatorStatus,
      )
    }

    func withMainStatus(_ newStatus: TaskStatus<Result>) -> Status {
      return copy(
        status: newStatus,
      )
    }

    func withAssetExporterStatus(_ newStatus: AssetExporterStatus) -> Status {
      return copy(
        assetExporterStatus: newStatus,
      )
    }

    func withCollectionExporterStatus(_ newStatus: TaskStatus<CollectionExporterResult>) -> Status {
      return copy(
        collectionExporterStatus: newStatus,
      )
    }

    func withFileExporterStatus(_ newStatus: FileExporterStatus) -> Status {
      return copy(
        fileExporterStatus: newStatus,
      )
    }

    func withSymlinkCreatorStatus(_ newStatus: TaskStatus<EmptyTaskSuccess>) -> Status {
      return copy(
        symlinkCreatorStatus: newStatus,
      )
    }
  }

  internal init(
    exportBaseDir: URL,
    photokit: PhotokitProtocol,
    exporterDB: ExporterDB,
    photosDB: PhotosDBProtocol,
    fileManager: ExporterFileManagerProtocol,
    logger: Logger,
    timeProvider: TimeProvider,
    expiryDays: Int = 30,
    scoreThreshold: Int64 = 850000000,
  ) {
    self.exportBaseDir = exportBaseDir
    self.photokit = photokit
    self.exporterDB = exporterDB
    self.fileManager = fileManager
    self.logger = ClassLogger(className: "PhotosExporterLib", logger: logger)
    self.timeProvider = timeProvider

    let albumsDirURL = exportBaseDir.appending(path: "albums")
    let filesDirURL = exportBaseDir.appending(path: "files")
    let locationsDirURL = exportBaseDir.appending(path: "locations")
    let topShotsDirURL = exportBaseDir.appending(path: "top-shots")

    self.assetExporter = AssetExporter(
      exporterDB: exporterDB,
      photosDB: photosDB,
      photokit: photokit,
      logger: logger,
      timeProvider: timeProvider,
      expiryDays: expiryDays,
    )

    self.collectionExporter = CollectionExporter(
      exporterDB: exporterDB,
      photokit: photokit,
      timeProvider: timeProvider,
      logger: logger,
    )

    self.fileExporter = FileExporter(
      filesDirURL: filesDirURL,
      exporterDB: exporterDB,
      photokit: photokit,
      fileManager: self.fileManager,
      timeProvider: timeProvider,
      logger: logger,
    )

    self.symlinkCreator = SymlinkCreator(
      albumsDirURL: albumsDirURL,
      filesDirURL: filesDirURL,
      locationsDirURL: locationsDirURL,
      topShotsDirURL: topShotsDirURL,
      exporterDB: exporterDB,
      fileManager: fileManager,
      scoreThreshold: scoreThreshold,
      timeProvider: timeProvider,
      logger: logger,
    )
  }

  public static func create(
    exportBaseDir: URL,
    logger: Logger? = nil,
    expiryDays: Int = 30,
    scoreThreshold: Int64 = 850000000,
  ) async throws -> PhotosExporterLib {
    let classLogger = ClassLogger(className: "PhotosExporterLib", logger: logger)

    do {
      classLogger.info("Creating export folder...")
      if try await ExporterFileManager.shared.createDirectory(url: exportBaseDir) == .exists {
        classLogger.trace("Export folder already exists")
      } else {
        classLogger.trace("Export folder created")
      }

      try self.copyPhotosDB(exportBaseDir: exportBaseDir, logger: classLogger)
    } catch {
      classLogger.critical("Failed to set up Exporter directory")
      throw error
    }

    return PhotosExporterLib(
      exportBaseDir: exportBaseDir,
      photokit: Photokit(logger: classLogger.logger),
      exporterDB: try ExporterDB(
        exportDBPath: exportBaseDir.appending(path: "export.sqlite"),
        logger: classLogger.logger,
      ),
      photosDB: try PhotosDB(
        photosDBPath: exportBaseDir.appending(path: "Photos.sqlite"),
        logger: classLogger.logger,
      ),
      fileManager: ExporterFileManager.shared,
      logger: classLogger.logger,
      timeProvider: DefaultTimeProvider.shared,
      expiryDays: expiryDays,
      scoreThreshold: scoreThreshold,
    )
  }

  private static func copyPhotosDB(exportBaseDir: URL, logger: ClassLogger) throws {
    guard let picturesDirURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first else {
      throw Error.picturesDirectoryNotFound
    }

    let photosLibraryURL = picturesDirURL.appending(path: "Photos Library.photoslibrary")
    guard FileManager.default.fileExists(atPath: photosLibraryURL.path(percentEncoded: false)) else {
      throw Error.photosLibraryNotFound(photosLibraryURL.path(percentEncoded: false))
    }

    let photosLibraryDatabaseDirURL = photosLibraryURL.appending(path: "database")
    let dbFilesToCopy = [
      ("Photos.sqlite", true),
      ("Photos.sqlite-shm", false),
      ("Photos.sqlite-wal", false),
    ]

    logger.debug("Making a copy of Photos SQLite DB...")
    for (dbFile, isRequired) in dbFilesToCopy {
      let src = photosLibraryDatabaseDirURL.appending(path: dbFile)
      let dest = exportBaseDir.appending(path: dbFile)

      if !FileManager.default.fileExists(atPath: src.path(percentEncoded: false)) {
        if isRequired {
          throw Error.missingPhotosDBFile(dbFile)
        }
      } else {
        if FileManager.default.fileExists(atPath: dest.path(percentEncoded: false)) {
          logger.trace("Removing previous copy of Photos DB file", [
            "dest": "\(dest.path(percentEncoded: false))"
          ])
          try FileManager.default.removeItem(at: dest)
        }

        logger.trace("Copying Photos database file", [
          "src": "\(src.path(percentEncoded: false))",
          "dest": "\(dest.path(percentEncoded: false))",
        ])
        try FileManager.default.copyItem(at: src, to: dest)
        logger.trace("Photos database file copied", [
          "dest": "\(dest.path(percentEncoded: false))"
        ])
      }
    }
  }

  public static func authorisePhotos() async throws {
    try await Photokit.authorisePhotos()
  }

  public func lastRun() throws -> HistoryEntry? {
    return try exporterDB.getLatestExportResultHistoryEntry()?.toPublicEntry()
  }

  public func exportHistory() throws -> [HistoryEntry] {
    return try exporterDB.getExportResultHistoryEntries(limit: 100, offset: 0).map { historyEntry in
      historyEntry.toPublicEntry()
    }
  }

  // swiftlint:disable:next cyclomatic_complexity function_body_length
  public func export(
    assetExportEnabled: Bool = true,
    collectionExportEnabled: Bool = true,
    fileExporterEnabled: Bool = true,
    symlinkCreatorEnabled: Bool = true,
  ) -> AsyncThrowingStream<
  Status,
  Swift.Error
  > {
    AsyncThrowingStream(
      bufferingPolicy: .bufferingNewest(10)
    ) { continuation in
      Task {
        var status: Status = Status.notStarted()
        let startTime = await timeProvider.getDate()

        do {
          logger.info("Running Export...")
          status = status.withMainStatus(.running(nil))
          continuation.yield(status)

          guard !Task.isCancelled else {
            logger.warning("Export Task cancelled")
            continuation.yield(status.withMainStatus(.cancelled))
            continuation.finish()
            return
          }

          var assetExporterResult: AssetExporterResult = AssetExporterResult.empty()
          for try await assetExporterStatus in assetExporter.export(isEnabled: assetExportEnabled) {
            switch assetExporterStatus.status {
            case .notStarted, .skipped, .cancelled: break
            case .running:
              status = status.withAssetExporterStatus(assetExporterStatus)
              continuation.yield(status)
            case .failed(let error):
              status = status
                .withMainStatus(.failed(error))
                .withAssetExporterStatus(assetExporterStatus)
              continuation.yield(status)
              continuation.finish(throwing: Error.unexpectedError("\(error)"))
              return
            case .complete(let result):
              assetExporterResult = result
              status = status.withAssetExporterStatus(assetExporterStatus)
              continuation.yield(status)
            }
          }

          guard !Task.isCancelled else {
            logger.warning("Export Task cancelled")
            continuation.yield(status.withMainStatus(.cancelled))
            continuation.finish()
            return
          }

          var collectionExporterResult: CollectionExporterResult = CollectionExporterResult.empty()
          for try await collectionExportStatus in collectionExporter.export(isEnabled: collectionExportEnabled) {
            switch collectionExportStatus {
            case .notStarted, .skipped, .cancelled: break
            case .running:
              status = status.withCollectionExporterStatus(collectionExportStatus)
              continuation.yield(status)
            case .failed(let error):
              status = status
                .withMainStatus(.failed(error))
                .withCollectionExporterStatus(collectionExportStatus)
              continuation.yield(status)
              continuation.finish(throwing: Error.unexpectedError("\(error)"))
              return
            case .complete(let result):
              collectionExporterResult = result
              status = status.withCollectionExporterStatus(collectionExportStatus)
              continuation.yield(status)
            }
          }

          guard !Task.isCancelled else {
            logger.warning("Export Task cancelled")
            continuation.yield(status.withMainStatus(.cancelled))
            continuation.finish()
            return
          }

          var fileExporterResult: FileExporterResultWithRemoved = FileExporterResultWithRemoved.empty()
          for try await fileExporterStatus in fileExporter.run(isEnabled: fileExporterEnabled) {
            switch fileExporterStatus.status {
            case .notStarted, .skipped, .cancelled: break
            case .running:
              status = status.withFileExporterStatus(fileExporterStatus)
              continuation.yield(status)
            case .failed(let error):
              status = status
                .withMainStatus(.failed(error))
                .withFileExporterStatus(fileExporterStatus)
              continuation.yield(status)
              continuation.finish(throwing: Error.unexpectedError("\(error)"))
              return
            case .complete(let result):
              fileExporterResult = result
              status = status.withFileExporterStatus(fileExporterStatus)
              continuation.yield(status)
            }
          }

          guard !Task.isCancelled else {
            logger.warning("Export Task cancelled")
            continuation.yield(status.withMainStatus(.cancelled))
            continuation.finish()
            return
          }

          for try await symlinkCreatorStatus in symlinkCreator.create(isEnabled: symlinkCreatorEnabled) {
            switch symlinkCreatorStatus {
            case .notStarted, .skipped, .cancelled: break
            case .running:
              status = status.withSymlinkCreatorStatus(symlinkCreatorStatus)
              continuation.yield(status)
            case .failed(let error):
              status = status
                .withMainStatus(.failed(error))
                .withSymlinkCreatorStatus(symlinkCreatorStatus)
              continuation.yield(status)
              continuation.finish(throwing: Error.unexpectedError("\(error)"))
              return
            case .complete:
              status = status.withSymlinkCreatorStatus(symlinkCreatorStatus)
              continuation.yield(status)
            }
          }

          let runTime = await timeProvider.secondsPassedSince(startTime)
          let exportResult = Result(
            assetExport: assetExporterResult.copy(
              fileMarkedForDeletion:
                assetExporterResult.fileMarkedForDeletion
                + fileExporterResult.fileMarkedForDeletion
            ),
            collectionExport: collectionExporterResult,
            fileExport: fileExporterResult.result,
            runTime: runTime,
          )

          logger.debug("Writing Export Result History entry to DB...")
          let assetCount = try exporterDB.countAssets()
          let fileCount = try exporterDB.countFiles()
          let albumCount = try exporterDB.countAlbums()
          let folderCount = try exporterDB.countFolders()
          let fileSizeTotal = try exporterDB.sumFileSizes()

          let historyEntry = ExportResultHistoryEntry(
            id: UUID().uuidString,
            createdAt: await timeProvider.getDate(),
            exportResult: exportResult,
            assetCount: assetCount,
            fileCount: fileCount,
            albumCount: albumCount,
            folderCount: folderCount,
            fileSizeTotal: fileSizeTotal ?? 0,
            runTime: Decimal(runTime),
          )
          _ = try exporterDB.insertExportResultHistoryEntry(entry: historyEntry)

          logger.info("Export complete in \(runTime)s")
          status = status.withMainStatus(.complete(exportResult))
          continuation.yield(status)
          continuation.finish()
        } catch {
          continuation.yield(
            status.withMainStatus(.failed("\(error)"))
          )
          continuation.finish(throwing: Error.unexpectedError("\(error)"))
        }
      }
    }
  }
}

extension PhotosExporterLib.Result: DiffableStruct {
  func getStructDiff(_ other: PhotosExporterLib.Result) -> StructDiff {
    return StructDiff()
      .add(diffProperty(other, \.assetExport))
      .add(diffProperty(other, \.collectionExport))
      .add(diffProperty(other, \.fileExport))
  }
}
