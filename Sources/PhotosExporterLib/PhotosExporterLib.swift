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

// swiftlint:disable:next type_body_length
public struct PhotosExporterLib {
  public let exportBaseDir: URL
  public let runStatus: Status

  private let photokit: PhotokitProtocol
  private let exporterDB: ExporterDB
  private let fileManager: ExporterFileManagerProtocol
  private let logger: ClassLogger
  private let timeProvider: TimeProvider

  private let assetExporter: AssetExporter
  private let collectionExporter: CollectionExporter
  private let fileExporter: FileExporter
  private let symlinkCreator: SymlinkCreator

  public struct Result: Codable, Sendable, Equatable {
    public let assetExport: AssetExporterResult
    public let collectionExport: CollectionExporterResult
    public let fileExport: FileExporterResult

    public static func empty() -> Result {
      return Result(
        assetExport: AssetExporterResult.empty(),
        collectionExport: CollectionExporterResult.empty(),
        fileExport: FileExporterResult.empty()
      )
    }
  }

  public enum Error: Swift.Error {
    case picturesDirectoryNotFound
    case photosLibraryNotFound(String)
    case missingPhotosDBFile(String)
    case unexpectedError(String)
  }

  public enum RunState: Equatable {
    case notStarted, skipped, running
    case complete(Double)
    case failed(String)
  }

  @Observable
  public class RunStatus {
    public var currentState: RunState {
      currentStateInternal
    }
    internal var currentStateInternal: RunState

    public init() {
      self.currentStateInternal = .notStarted
    }

    internal func start() {
      self.currentStateInternal = .running
    }

    internal func skipped() {
      self.currentStateInternal = .skipped
    }

    internal func complete(runTime: Double) {
      self.currentStateInternal = .complete(runTime)
    }

    internal func failed(error: String) {
      self.currentStateInternal = .failed(error)
    }
  }

  @Observable
  public class RunStatusWithProgress: RunStatus {
    public private(set) var progress: Double = 0
    private var toProcess: Int = 0
    private var processed: Int = 0

    internal func startProgress(toProcess: Int) {
      self.toProcess = toProcess
    }

    override internal func complete(runTime: Double) {
      self.progress = 1
      super.complete(runTime: runTime)
    }

    override internal func failed(error: String) {
      reset()
      super.failed(error: error)
    }

    func reset() {
      self.progress = 0
      self.processed = 0
      self.toProcess = 0
    }

    func processed(count: Int = 1) {
      self.processed += count
      self.progress = Double(processed) / Double(toProcess)
    }
  }

  @Observable
  public class Status: RunStatus {
    public let assetExporterStatus: AssetExporterStatus
    public let collectionExporterStatus: CollectionExporterStatus
    public let fileExporterStatus: FileExporterStatus
    public let symlinkCreatorStatus: SymlinkCreatorStatus

    public init(
      assetExporterStatus: AssetExporterStatus,
      collectionExporterStatus: CollectionExporterStatus,
      fileExporterStatus: FileExporterStatus,
      symlinkCreatorStatus: SymlinkCreatorStatus,
    ) {
      self.assetExporterStatus = assetExporterStatus
      self.collectionExporterStatus = collectionExporterStatus
      self.fileExporterStatus = fileExporterStatus
      self.symlinkCreatorStatus = symlinkCreatorStatus
      super.init()
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

    self.runStatus = Status(
      assetExporterStatus: self.assetExporter.runStatus,
      collectionExporterStatus: self.collectionExporter.runStatus,
      fileExporterStatus: self.fileExporter.runStatus,
      symlinkCreatorStatus: self.symlinkCreator.runStatus,
    )
  }

  public static func create(
    exportBaseDir: URL,
    logger: Logger? = nil,
    expiryDays: Int = 30,
    scoreThreshold: Int64 = 850000000,
  ) throws -> PhotosExporterLib {
    let classLogger = ClassLogger(className: "PhotosExporterLib", logger: logger)

    do {
      classLogger.info("Creating export folder...")
      if try ExporterFileManager.shared.createDirectory(url: exportBaseDir) == .exists {
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

  public func export(
    assetExportEnabled: Bool = true,
    collectionExportEnabled: Bool = true,
    fileManagerEnabled: Bool = true,
    symlinkCreatorEnabled: Bool = true,
  ) async throws -> Result {
    do {
      logger.info("Running Export...")
      runStatus.start()
      let startDate = timeProvider.getDate()

      let exportAssetResult = try await assetExporter.export(isEnabled: assetExportEnabled)
      let albumExportResult = try collectionExporter.export(isEnabled: collectionExportEnabled)
      let fileManagerResult = try await fileExporter.run(isEnabled: fileManagerEnabled)
      try symlinkCreator.create(isEnabled: symlinkCreatorEnabled)

      let exportResult = Result(
        assetExport: exportAssetResult.copy(
          fileMarkedForDeletion: exportAssetResult.fileMarkedForDeletion + fileManagerResult.fileMarkedForDeletion
        ),
        collectionExport: albumExportResult,
        fileExport: fileManagerResult.result,
      )

      logger.debug("Writing Export Result History entry to DB...")
      let assetCount = try exporterDB.countAssets()
      let fileCount = try exporterDB.countFiles()
      let albumCount = try exporterDB.countAlbums()
      let folderCount = try exporterDB.countFolders()
      let fileSizeTotal = try exporterDB.sumFileSizes()

      let runTime = timeProvider.secondsPassedSince(startDate)
      let historyEntry = ExportResultHistoryEntry(
        id: UUID().uuidString,
        createdAt: timeProvider.getDate(),
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
      runStatus.complete(runTime: runTime)
      return exportResult
    } catch {
      runStatus.failed(error: "\(error)")
      throw Error.unexpectedError("\(error)")
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
