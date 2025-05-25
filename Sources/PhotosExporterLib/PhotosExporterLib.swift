import Foundation
import Photos
import Logging

public struct PhotosExporterLib {
  private let exportBaseDirURL: URL
  private let albumsDirURL: URL
  private let filesDirURL: URL
  private let photokit: PhotokitProtocol
  private let exporterDB: ExporterDB
  private let fileManager: ExporterFileManagerProtocol
  private let logger: ClassLogger
  private let timeProvider: TimeProvider

  private let assetExporter: AssetExporter
  private let collectionExporter: CollectionExporter
  private let fileCopier: FileCopier
  private let symlinkCreator: SymlinkCreator

  internal init(
    exportBaseDir: String,
    photokit: PhotokitProtocol,
    exporterDB: ExporterDB,
    photosDB: PhotosDBProtocol,
    fileManager: ExporterFileManagerProtocol,
    logger: Logger,
    timeProvider: TimeProvider
  ) {
    self.exportBaseDirURL = URL(filePath: exportBaseDir)
    self.albumsDirURL = exportBaseDirURL.appending(path: "albums")
    self.filesDirURL = exportBaseDirURL.appending(path: "files")
    self.photokit = photokit
    self.exporterDB = exporterDB
    self.fileManager = fileManager
    self.logger = ClassLogger(logger: logger, className: "PhotosExporterLib")
    self.timeProvider = timeProvider

    self.assetExporter = AssetExporter(
      exporterDB: exporterDB,
      photosDB: photosDB,
      photokit: photokit,
      logger: logger,
      timeProvider: timeProvider,
    )

    self.collectionExporter = CollectionExporter(
      exporterDB: exporterDB,
      photokit: photokit,
      timeProvider: timeProvider,
      logger: logger,
    )

    self.fileCopier = FileCopier(
      exportBaseDirURL: self.exportBaseDirURL,
      exporterDB: exporterDB,
      photokit: photokit,
      fileManager: self.fileManager,
      timeProvider: timeProvider,
      logger: logger,
    )

    self.symlinkCreator = SymlinkCreator(
      albumsDirURL: self.albumsDirURL,
      filesDirURL: self.filesDirURL,
      exporterDB: exporterDB,
      fileManager: fileManager,
      timeProvider: timeProvider,
      logger: logger,
    )
  }

  init(
    exportBaseDir: String,
    loggerOpt: Logger? = nil,
  ) async throws {
    let logger: Logger

    if let customLogger = loggerOpt {
      logger = customLogger
    } else {
      var defaultLogger = Logger(label: "io.motns.PhotosExporter")
      defaultLogger.logLevel = .info
      logger = defaultLogger
    }

    let classLogger = ClassLogger(logger: logger, className: "PhotosExporterLib")

    do {
      classLogger.info("Creating export folder...")
      if try ExporterFileManager.shared.createDirectory(path: exportBaseDir) == .exists {
        classLogger.trace("Export folder already exists")
      } else {
        classLogger.trace("Export folder created")
      }

      try PhotosExporterLib.copyPhotosDB(exportBaseDir: exportBaseDir, logger: classLogger)
    } catch {
      classLogger.critical("Failed to set up Exporter directory")
      throw error
    }

    self.init(
      exportBaseDir: exportBaseDir,
      photokit: try await Photokit(logger: logger),
      exporterDB: try ExporterDB(
        exportDBPath: "\(exportBaseDir)/export.sqlite",
        logger: logger,
      ),
      photosDB: try PhotosDB(photosDBPath: "\(exportBaseDir)/Photos.sqlite", logger: logger),
      fileManager: ExporterFileManager.shared,
      logger: logger,
      timeProvider: DefaultTimeProvider.shared,
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

  public func export(
    assetExportEnabled: Bool = true,
    collectionExportEnabled: Bool = true,
    fileCopyEnabled: Bool = true,
  ) async throws -> ExportResult {
    logger.info("Running Export...")
    let startDate = timeProvider.getDate()

    let exportAssetResult = try await assetExporter.export(isEnabled: assetExportEnabled)
    let albumExportResult = try collectionExporter.export(isEnabled: collectionExportEnabled)
    let copyResults = try await fileCopier.copy(isEnabled: fileCopyEnabled)
    try symlinkCreator.create()

    logger.info("Export complete in \(timeProvider.secondsPassedSince(startDate))s")
    return ExportResult(
      assetExport: exportAssetResult,
      collectionExport: albumExportResult,
      fileCopy: copyResults,
    )
  }
}

public enum PhotosExporterError: Error {
  case picturesDirectoryNotFound
  case photosLibraryNotFound(String)
  case missingPhotosDBFile(String)
  case unexpectedError(String)
}

public struct ExportResult: Sendable, Equatable {
  let assetExport: AssetExportResult
  let collectionExport: CollectionExportResult
  let fileCopy: FileCopyResult

  static func empty() -> ExportResult {
    return ExportResult(
      assetExport: AssetExportResult.empty(),
      collectionExport: CollectionExportResult.empty(),
      fileCopy: FileCopyResult.empty()
    )
  }
}
