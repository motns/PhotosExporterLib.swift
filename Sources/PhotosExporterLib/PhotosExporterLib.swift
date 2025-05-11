import Foundation
import Photos
import Logging

public actor PhotosExporterLib {
  private let exportBaseDirURL: URL
  private let albumsDirURL: URL
  private let filesDirURL: URL
  private let photokit: PhotokitProtocol
  private let exporterDB: ExporterDB
  private let photosDB: PhotosDBProtocol
  private let countryLookup: CachedLookupTable
  private let cityLookup: CachedLookupTable
  private let logger: ClassLogger
  private let timeProvider: TimeProvider

  internal init(
    exportBaseDir: String,
    photokit: PhotokitProtocol,
    exporterDB: ExporterDB,
    photosDB: PhotosDBProtocol,
    countryLookup: CachedLookupTable,
    cityLookup: CachedLookupTable,
    classLogger: ClassLogger,
    timeProvider: TimeProvider
  ) {
    self.exportBaseDirURL = URL(filePath: exportBaseDir)
    self.albumsDirURL = exportBaseDirURL.appending(path: "albums")
    self.filesDirURL = exportBaseDirURL.appending(path: "files")
    self.photokit = photokit
    self.exporterDB = exporterDB
    self.photosDB = photosDB
    self.countryLookup = countryLookup
    self.cityLookup = cityLookup
    self.logger = classLogger
    self.timeProvider = timeProvider
  }

  public static func create(
    exportBaseDir: String,
    loggerOpt: Logger? = nil,
    timeProviderOpt: TimeProvider? = nil
  ) async throws -> PhotosExporterLib {
    let logger: Logger
    
    if let l = loggerOpt {
      logger = l
    } else {
      var l = Logger(label: "io.motns.PhotosExporter")
      l.logLevel = .info
      logger = l
    }

    let classLogger = ClassLogger(logger: logger, className: "PhotosExporterLib")

    do {
      classLogger.info("Creating export folder...")
      if try FileHelper.createDirectory(path: exportBaseDir) {
        classLogger.trace("Export folder created")
      } else {
        classLogger.trace("Export folder already exists")
      }

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

      classLogger.debug("Making a copy of Photos SQLite DB...")
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
            classLogger.trace("Removing previous copy of Photos DB file", [
              "dest": "\(dest.path(percentEncoded: false))"
            ])
            try FileManager.default.removeItem(at: dest)
          }

          classLogger.trace("Copying Photos database file", [
            "src": "\(src.path(percentEncoded: false))",
            "dest": "\(dest.path(percentEncoded: false))",
          ])
          try FileManager.default.copyItem(at: src, to: dest)
          classLogger.trace("Photos database file copied", [
            "dest": "\(dest.path(percentEncoded: false))"
          ])
        }
      }
    } catch {
      classLogger.critical("Failed to set up Exporter directory")
      throw error
    }

    let timeProvider = timeProviderOpt ?? DefaultTimeProvider.shared
    let exporterDB = try await ExporterDB(
      exportDBPath: "\(exportBaseDir)/export.sqlite",
      logger: logger,
      timeProvider: timeProvider,
    )

    return PhotosExporterLib(
      exportBaseDir: exportBaseDir,
      photokit: try await Photokit(logger: logger),
      exporterDB: exporterDB,
      photosDB: try PhotosDB(photosDBPath: "\(exportBaseDir)/Photos.sqlite", logger: logger),
      countryLookup: CachedLookupTable(table: .country, exporterDB: exporterDB, logger: logger),
      cityLookup: CachedLookupTable(table: .city, exporterDB: exporterDB, logger: logger),
      classLogger: classLogger,
      timeProvider: timeProvider,
    )
  }

  public func export(
    assetExportEnabled: Bool = true,
    collectionExportEnabled: Bool = true,
    fileCopyEnabled: Bool = true,
  ) async throws -> ExportResult {
    logger.info("Running Export...")
    let startDate = await timeProvider.getDate()

    let exportAssetResult = try await exportAssetsToDB(isEnabled: assetExportEnabled)
    let albumExportResult = try await exportCollections(isEnabled: collectionExportEnabled)
    let copyResults = try await copyFiles(isEnabled: fileCopyEnabled)
    try await createAlbumSymlinks()

    logger.info("Export complete in \(await timeProvider.secondsPassedSince(startDate))s")
    return ExportResult(
      assetExport: exportAssetResult,
      collectionExport: albumExportResult,
      fileCopy: copyResults,
    )
  }

  private func exportAssetsToDB(isEnabled: Bool) async throws -> AssetExportResult {
    guard isEnabled else {
      logger.warning("Asset export disabled - skipping")
      return AssetExportResult.empty()
    }
    logger.info("Exporting Assets to local DB...")
    let startDate = await timeProvider.getDate()

    let assetLocationsById = try await photosDB.getAllAssetLocationsById()
    let allPhotokitAssets = await photokit.getAllAssets()
    var assetResults = [UpsertResult?]()
    var fileResults = [UpsertResult?]()

    for photokitAsset in allPhotokitAssets {
      let assetLocationOpt = assetLocationsById[photokitAsset.uuid]

      let (countryOpt, countryIdOpt): (String?, Int64?) = switch assetLocationOpt?.country {
        case .none: (nil, nil)
        case .some(let country): (country, try await countryLookup.getIdByName(name: country))
      }

      let (cityOpt, cityIdOpt): (String?, Int64?) = switch assetLocationOpt?.city {
        case .none: (nil, nil)
        case .some(let city): (city, try await cityLookup.getIdByName(name: city))
      }

      let exportedAssetOpt = await ExportedAsset.fromPhotokitAsset(
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
      assetResults.append(try await exporterDB.upsertAsset(asset: exportedAsset))

      for photokitResource in photokitAsset.resources {
        // Filter out supplementary files like adjustment data
        guard photokitResource.fileTypeOpt != nil else {
          logger.trace(
            "Unsupported file type for Asset Resource",
            [
              "asset_id": "\(photokitAsset.id)",
              "resource_type": "\(photokitResource.assetResourceType)",
              "original_file_name": "\(photokitResource.originalFileName)",
            ]
          )
          continue
        }

        let exportedFileOpt = await ExportedFile.fromPhotokitAssetResource(
          asset: photokitAsset,
          resource: photokitResource,
          countryOpt: countryOpt,
          cityOpt: cityOpt,
          now: self.timeProvider.getDate()
        )

        guard let exportedFile = exportedFileOpt else {
          logger.warning(
            "Could not convert Photokit Asset Resource to Exported File",
            [
              "asset_id": "\(photokitAsset.id)",
              "resource_type": "\(photokitResource.assetResourceType)",
              "original_file_name": "\(photokitResource.originalFileName)",
            ]
          )
          fileResults.append(nil)
          continue
        }

        fileResults.append(try await exporterDB.upsertFile(file: exportedFile))
      }
    }

    var assetInsertCnt = 0
    var assetUpdateCnt = 0
    var assetUnchangedCnt = 0
    var assetSkippedCnt = 0

    for assetResult in assetResults {
      switch assetResult {
        case .none: assetSkippedCnt += 1
        case .some(let upsertResult): switch upsertResult {
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
        case .some(let upsertResult): switch upsertResult {
          case .insert: fileInsertCnt += 1
          case .update: fileUpdateCnt += 1
          case .nochange: fileUnchangedCnt += 1
        }
      }
    }

    logger.info("Asset export complete in \(await timeProvider.secondsPassedSince(startDate))s")
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

  private func exportCollections(isEnabled: Bool) async throws -> CollectionExportResult {
    guard isEnabled else {
      logger.warning("Collection export disabled - skipping")
      return CollectionExportResult.empty()
    }
    logger.info("Exporting Folders and Albums to local DB...")
    let startDate = await timeProvider.getDate()

    let rootFolderResult = try await processPhotokitFolder(
      folder: try await self.photokit.getRootFolder()
    )

    var albumInsertedCnt = 0
    var albumUpdatedCnt = 0
    var albumUnchangedCnt = 0

    logger.debug("Processing shared Albums...")
    let sharedAlbums = try await self.photokit.getSharedAlbums()
    for sharedAlbum in sharedAlbums {
      let albumUpsertRes = try await self.exporterDB.upsertAlbum(album: ExportedAlbum.fromPhotokitAlbum(album: sharedAlbum))
      switch albumUpsertRes {
        case .insert: albumInsertedCnt += 1
        case .update: albumUpdatedCnt += 1
        case .nochange: albumUnchangedCnt += 1
      }
    }

    logger.info("Folder and Album export complete in \(await timeProvider.secondsPassedSince(startDate))s")
    return rootFolderResult.copy(
      albumInserted: rootFolderResult.albumInserted + albumInsertedCnt,
      albumUpdated: rootFolderResult.albumUpdated + albumUpdatedCnt,
      albumUnchanged: rootFolderResult.albumUnchanged + albumUnchangedCnt,
    )
  }

  private func processPhotokitFolder(folder: PhotokitFolder) async throws -> CollectionExportResult {
    let loggerMetadata: Logger.Metadata = [
      "folder_id": "\(folder.id)"
    ]
    logger.debug("Processing Folder...", loggerMetadata)

    var folderInsertedCnt = 0
    var folderUpdatedCnt = 0
    var folderUnchangedCnt = 0
    var albumInsertedCnt = 0
    var albumUpdatedCnt = 0
    var albumUnchangedCnt = 0

    let exportedFolder = ExportedFolder.fromPhotokitFolder(folder: folder)
    let folderUpsertRes = try await self.exporterDB.upsertFolder(folder: exportedFolder)
    switch folderUpsertRes {
      case .insert: folderInsertedCnt += 1
      case .update: folderUpdatedCnt += 1
      case .nochange: folderUnchangedCnt += 1
    }

    for album in folder.albums {
      let albumUpsertRes = try await self.exporterDB.upsertAlbum(album: ExportedAlbum.fromPhotokitAlbum(album: album))
      switch albumUpsertRes {
        case .insert: albumInsertedCnt += 1
        case .update: albumUpdatedCnt += 1
        case .nochange: albumUnchangedCnt += 1
      }
    }

    for subfolder in folder.subfolders {
      let subfolderRes = try await processPhotokitFolder(folder: subfolder)
      folderInsertedCnt += subfolderRes.folderInserted
      folderUpdatedCnt += subfolderRes.folderUpdated
      folderUnchangedCnt += subfolderRes.folderUnchanged
      albumInsertedCnt += subfolderRes.albumInserted
      albumUpdatedCnt += subfolderRes.albumUpdated
      albumUnchangedCnt += subfolderRes.albumUnchanged
    }

    return CollectionExportResult(
      folderInserted: folderInsertedCnt,
      folderUpdated: folderUpdatedCnt,
      folderUnchanged: folderUnchangedCnt,
      albumInserted: albumInsertedCnt,
      albumUpdated: albumUpdatedCnt,
      albumUnchanged: albumUnchangedCnt,
    )
  }

  private func copyFiles(isEnabled: Bool) async throws -> FileCopyResults {
    guard isEnabled else {
      logger.warning("File copying disabled - skipping")
      return FileCopyResults.empty()
    }
    let startDate = await timeProvider.getDate()

    logger.info("Getting Files to copy from local DB...")
    let filesToCopy = try await exporterDB.getFilesToCopy()

    guard filesToCopy.count > 0 else {
      logger.info("No Files to copy")
      return FileCopyResults(copied: 0, removed: 0)
    }

    logger.info("Copying files...")
    var copiedCount = 0
    var removedCount = 0
    for fileToCopy in filesToCopy {
      let destinationDirURL = filesDirURL.appending(path: fileToCopy.importedFileDir)
      let loggerMetadata: Logger.Metadata = [
        "asset_id": "\(fileToCopy.assetId)",
        "file_type": "\(fileToCopy.fileType)",
        "original_file_name": "\(fileToCopy.originalFileName)",
      ]

      if try FileHelper.createDirectory(path: destinationDirURL.path(percentEncoded: false)) {
        logger.trace("Created destination directory: \(destinationDirURL.path(percentEncoded: false))")
      }
      let destinationFileURL = destinationDirURL.appending(path: fileToCopy.importedFileName)

      let copyResult = try await photokit.copyResource(
        assetId: fileToCopy.assetId,
        fileType: fileToCopy.fileType,
        originalFileName: fileToCopy.originalFileName,
        destination: destinationFileURL
      )

      if copyResult == .exists {
        // These could be due to the Exporter previously crashing before updating the
        // record in the DB, but it's also possible that two or more assets are using
        // the exact same Resource - this happens when you create virtual copies in the
        // Photos library.
        logger.debug("File was already copied but not updated in DB", loggerMetadata)
      }

      switch copyResult {
        case .removed:
          logger.trace("File removed in Photos - marking as deleted in DB...", loggerMetadata)
          removedCount += 1
          let updatedFile = fileToCopy.copy(
            isDeleted: true,
            deletedAt: await timeProvider.getDate()
          )
          _ = try await exporterDB.upsertFile(file: updatedFile)
        case .exists, .copied:
          logger.trace("File successfully copied - updating DB...", loggerMetadata)
          copiedCount += 1
          let updatedFile = fileToCopy.copy(
            wasCopied: true
          )
          _ = try await exporterDB.upsertFile(file: updatedFile)
      }
      logger.trace("File updated in DB", loggerMetadata)
    }

    logger.info("File copying complete in \(await timeProvider.secondsPassedSince(startDate))s")
    return FileCopyResults(copied: copiedCount, removed: removedCount)
  }

  private func createAlbumSymlinks() async throws {
    logger.info("Removing and recreating Album folders...")
    let startDate = await timeProvider.getDate()

    if FileManager.default.fileExists(atPath: albumsDirURL.path(percentEncoded: false)) {
      try FileManager.default.removeItem(atPath: albumsDirURL.path(percentEncoded: false))
    }
    _ = try FileHelper.createDirectory(url: albumsDirURL)

    logger.debug("Creating Album directories and symlinks...")
    try await createAlbumFolderSymlinks(
      folderId: Photokit.RootFolderId,
      folderDirURL: albumsDirURL,
    )
    logger.info("Albums folders created in \(await timeProvider.secondsPassedSince(startDate))s")
  }

  private func createAlbumFolderSymlinks(folderId: String, folderDirURL: URL) async throws {
    logger.debug("Creating symlinks and directories for Folder...", [
      "folder_id": "\(folderId)",
      "folder_dir": "\(folderDirURL)",
    ])

    async let subfolders = exporterDB.getFoldersWithParent(parentId: folderId)
    async let albums = exporterDB.getAlbumsInFolder(folderId: folderId)

    for subfolder in try await subfolders {
      let pathSafeName = FileHelper.normaliseForPath(subfolder.name)

      if !pathSafeName.isEmpty {
        let subfolderDirURL = folderDirURL.appending(path: pathSafeName)

        logger.trace("Creating subdirectory for Subfolder...", [
          "folder_id": "\(subfolder.id)",
          "folder_dir": "\(subfolderDirURL.path(percentEncoded: false))",
        ])
        _ = try FileHelper.createDirectory(url: subfolderDirURL)

        try await createAlbumFolderSymlinks(
          folderId: subfolder.id,
          folderDirURL: subfolderDirURL,
        )
      } else {
        logger.warning("Cannot convert Folder name to path-safe version - skipping...", [
          "folder_id": "\(subfolder.id)",
          "name": "\(subfolder.name)",
        ])
      }
    }

    for album in try await albums {
      let pathSafeName = FileHelper.normaliseForPath(album.name)

      if !pathSafeName.isEmpty {
        let albumDirURL = folderDirURL.appending(path: pathSafeName)
        logger.trace("Creating subdirectory for Album...", [
          "album_id": "\(album.id)",
          "album_dir": "\(albumDirURL.path(percentEncoded: false))",
        ])
        _ = try FileHelper.createDirectory(url: albumDirURL)

        for file in try await exporterDB.getFilesForAlbum(albumId: album.id) {
          let linkSrc = filesDirURL
            .appending(path: file.importedFileDir)
            .appending(path: file.importedFileName)

          let linkDest = albumDirURL.appending(path: file.importedFileName)

          guard !FileManager.default.fileExists(atPath: linkDest.path(percentEncoded: false)) else {
            logger.trace("Symlink for Album File already exists - skipping", [
              "album_id": "\(album.id)",
              "link_src": "\(linkSrc.path(percentEncoded: false))",
              "link_dest": "\(linkDest.path(percentEncoded: false))",
            ])
            continue
          }

          logger.trace("Creating symlink for Album File...", [
            "album_id": "\(album.id)",
            "link_src": "\(linkSrc.path(percentEncoded: false))",
            "link_dest": "\(linkDest.path(percentEncoded: false))",
          ])
          try FileManager.default.createSymbolicLink(at: linkDest, withDestinationURL: linkSrc)
        }
      } else {
        logger.warning("Cannot convert Album name to path-safe version - skipping", [
          "album_id": "\(album.id)",
          "name": "\(album.name)",
        ])
      }
    }
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
  let fileCopy: FileCopyResults

  static func empty() -> ExportResult {
    return ExportResult(
      assetExport: AssetExportResult.empty(),
      collectionExport: CollectionExportResult.empty(),
      fileCopy: FileCopyResults.empty()
    )
  }
}

public struct CollectionExportResult: Sendable, Equatable {
  let folderInserted: Int
  let folderUpdated: Int
  let folderUnchanged: Int
  let albumInserted: Int
  let albumUpdated: Int
  let albumUnchanged: Int

  func copy(
    folderInserted: Int? = nil,
    folderUpdated: Int? = nil,
    folderUnchanged: Int? = nil,
    albumInserted: Int? = nil,
    albumUpdated: Int? = nil,
    albumUnchanged: Int? = nil,
  ) -> CollectionExportResult {
    return CollectionExportResult(
      folderInserted: folderInserted ?? self.folderInserted,
      folderUpdated: folderUpdated ?? self.folderUpdated,
      folderUnchanged: folderUnchanged ?? self.folderUnchanged,
      albumInserted: albumInserted ?? self.albumInserted,
      albumUpdated: albumUpdated ?? self.albumUpdated,
      albumUnchanged: albumUnchanged ?? self.albumUnchanged,
    )
  }

  static func empty() -> CollectionExportResult {
    return CollectionExportResult(
      folderInserted: 0,
      folderUpdated: 0,
      folderUnchanged: 0,
      albumInserted: 0,
      albumUpdated: 0,
      albumUnchanged: 0
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

public struct FileCopyResults: Sendable, Equatable {
  let copied: Int
  let removed: Int

  static func empty() -> FileCopyResults {
    return FileCopyResults(copied: 0, removed: 0)
  }
}