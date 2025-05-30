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
      expiryDays: expiryDays,
    )

    self.collectionExporter = CollectionExporter(
      exporterDB: exporterDB,
      photokit: photokit,
      timeProvider: timeProvider,
      logger: logger,
    )

    self.fileExporter = FileExporter(
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
    logger: Logger? = nil,
    expiryDays: Int = 30,
  ) async throws {
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

      try PhotosExporterLib.copyPhotosDB(exportBaseDir: exportBaseDir, logger: classLogger)
    } catch {
      classLogger.critical("Failed to set up Exporter directory")
      throw error
    }

    self.init(
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
    fileManagerEnabled: Bool = true,
    symlinkCreatorEnabled: Bool = true,
  ) async throws -> ExportResult {
    logger.info("Running Export...")
    let startDate = timeProvider.getDate()

    let exportAssetResult = try await assetExporter.export(isEnabled: assetExportEnabled)
    let albumExportResult = try collectionExporter.export(isEnabled: collectionExportEnabled)
    let fileManagerResult = try await fileExporter.run(isEnabled: fileManagerEnabled)
    try symlinkCreator.create(isEnabled: symlinkCreatorEnabled)

    logger.info("Export complete in \(timeProvider.secondsPassedSince(startDate))s")
    return ExportResult(
      assetExport: exportAssetResult.copy(
        fileMarkedForDeletion: exportAssetResult.fileMarkedForDeletion + fileManagerResult.fileMarkedForDeletion
      ),
      collectionExport: albumExportResult,
      fileExport: fileManagerResult.result,
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
  let fileExport: FileExportResult

  static func empty() -> ExportResult {
    return ExportResult(
      assetExport: AssetExportResult.empty(),
      collectionExport: CollectionExportResult.empty(),
      fileExport: FileExportResult.empty()
    )
  }
}
