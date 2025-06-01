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

public struct PhotosExporterLib {
  private let exportBaseDirURL: URL
  private let photokit: PhotokitProtocol
  private let exporterDB: ExporterDB
  private let fileManager: ExporterFileManagerProtocol
  private let logger: ClassLogger
  private let timeProvider: TimeProvider

  private let assetExporter: AssetExporter
  private let collectionExporter: CollectionExporter
  private let fileExporter: FileExporter
  private let symlinkCreator: SymlinkCreator

  internal init(
    exportBaseDir: String,
    photokit: PhotokitProtocol,
    exporterDB: ExporterDB,
    photosDB: PhotosDBProtocol,
    fileManager: ExporterFileManagerProtocol,
    logger: Logger,
    timeProvider: TimeProvider,
    expiryDays: Int = 30,
    scoreThreshold: Int64 = 850000000,
  ) {
    self.exportBaseDirURL = URL(filePath: exportBaseDir)
    self.photokit = photokit
    self.exporterDB = exporterDB
    self.fileManager = fileManager
    self.logger = ClassLogger(logger: logger, className: "PhotosExporterLib")
    self.timeProvider = timeProvider

    let albumsDirURL = exportBaseDirURL.appending(path: "albums")
    let filesDirURL = exportBaseDirURL.appending(path: "files")
    let locationsDirURL = exportBaseDirURL.appending(path: "locations")
    let topShotsDirURL = exportBaseDirURL.appending(path: "top-shots")

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
    exportBaseDir: String,
    logger: Logger? = nil,
    expiryDays: Int = 30,
    scoreThreshold: Int64 = 850000000,
  ) async throws -> PhotosExporterLib {
    let loggerActual: Logger

    if let customLogger = logger {
      loggerActual = customLogger
    } else {
      var defaultLogger = Logger(label: "io.motns.PhotosExporter")
      defaultLogger.logLevel = .info
      loggerActual = defaultLogger
    }

    let classLogger = ClassLogger(logger: loggerActual, className: "PhotosExporterLib")

    do {
      classLogger.info("Creating export folder...")
      if try ExporterFileManager.shared.createDirectory(path: exportBaseDir) == .exists {
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
      photokit: try await Photokit(logger: loggerActual),
      exporterDB: try ExporterDB(
        exportDBPath: "\(exportBaseDir)/export.sqlite",
        logger: loggerActual,
      ),
      photosDB: try PhotosDB(photosDBPath: "\(exportBaseDir)/Photos.sqlite", logger: loggerActual),
      fileManager: ExporterFileManager.shared,
      logger: loggerActual,
      timeProvider: DefaultTimeProvider.shared,
      expiryDays: expiryDays,
      scoreThreshold: scoreThreshold,
    )
  }

  private static func copyPhotosDB(exportBaseDir: String, logger: ClassLogger) throws {
    guard let picturesDirURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first else {
      throw PhotosExporterError.picturesDirectoryNotFound
    }

    let photosLibraryURL = picturesDirURL.appending(path: "Photos Library.photoslibrary")
    guard FileManager.default.fileExists(atPath: photosLibraryURL.path(percentEncoded: false)) else {
      throw PhotosExporterError.photosLibraryNotFound(photosLibraryURL.path(percentEncoded: false))
    }

    let photosLibraryDatabaseDirURL = photosLibraryURL.appending(path: "database")
    let dbFilesToCopy = [
      ("Photos.sqlite", true),
      ("Photos.sqlite-shm", false),
      ("Photos.sqlite-wal", false),
    ]

    logger.debug("Making a copy of Photos SQLite DB...")
    let exportBaseDirURL = URL(filePath: exportBaseDir)
    for (dbFile, isRequired) in dbFilesToCopy {
      let src = photosLibraryDatabaseDirURL.appending(path: dbFile)
      let dest = exportBaseDirURL.appending(path: dbFile)

      if !FileManager.default.fileExists(atPath: src.path(percentEncoded: false)) {
        if isRequired {
          throw PhotosExporterError.missingPhotosDBFile(dbFile)
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

  public func lastRun() throws -> HistoryEntry? {
    return try exporterDB.getLatestExportResultHistoryEntry()?.toPublicEntry()
  }

  public func export(
    assetExportEnabled: Bool = true,
    collectionExportEnabled: Bool = true,
    fileManagerEnabled: Bool = true,
    symlinkCreatorEnabled: Bool = true,
  ) async throws -> ExportResult {
    logger.info("Running Export...")
    let startDate = timeProvider.getDate()

    let exportAssetResult = try await assetExporter.export(isEnabled: assetExportEnabled)
    let albumExportResult = try collectionExporter.export(isEnabled: collectionExportEnabled)
    let fileManagerResult = try await fileExporter.run(isEnabled: fileManagerEnabled)
    try symlinkCreator.create(isEnabled: symlinkCreatorEnabled)

    let exportResult = ExportResult(
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

    let historyEntry = ExportResultHistoryEntry(
      id: UUID().uuidString,
      createdAt: timeProvider.getDate(),
      exportResult: exportResult,
      assetCount: assetCount,
      fileCount: fileCount,
      albumCount: albumCount,
      folderCount: folderCount
    )
    _ = try exporterDB.insertExportResultHistoryEntry(entry: historyEntry)

    logger.info("Export complete in \(timeProvider.secondsPassedSince(startDate))s")
    return exportResult
  }
}

public enum PhotosExporterError: Error {
  case picturesDirectoryNotFound
  case photosLibraryNotFound(String)
  case missingPhotosDBFile(String)
  case unexpectedError(String)
}

public struct ExportResult: Codable, Sendable, Equatable {
  let assetExport: AssetExportResult
  let collectionExport: CollectionExportResult
  let fileExport: FileExportResult

  static func empty() -> ExportResult {
    return ExportResult(
      assetExport: AssetExportResult.empty(),
      collectionExport: CollectionExportResult.empty(),
      fileExport: FileExportResult.empty()
    )
  }
}
