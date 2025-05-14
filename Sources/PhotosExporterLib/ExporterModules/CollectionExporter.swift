import Logging

struct CollectionExporter {
  private let exporterDB: ExporterDB
  private let photokit: PhotokitProtocol
  private let timeProvider: TimeProvider
  private let logger: ClassLogger

  init(
    exporterDB: ExporterDB,
    photokit: PhotokitProtocol,
    timeProvider: TimeProvider,
    logger: Logger,
  ) {
    self.exporterDB = exporterDB
    self.photokit = photokit
    self.timeProvider = timeProvider
    self.logger = ClassLogger(logger: logger, className: "CollectionExporter")
  }

  func export(isEnabled: Bool = true) throws -> CollectionExportResult {
    guard isEnabled else {
      logger.warning("Collection export disabled - skipping")
      return CollectionExportResult.empty()
    }
    logger.info("Exporting Folders and Albums to local DB...")
    let startDate = timeProvider.getDate()

    let rootFolderResult = try processPhotokitFolder(
      folder: try self.photokit.getRootFolder()
    )

    var albumInsertedCnt = 0
    var albumUpdatedCnt = 0
    var albumUnchangedCnt = 0

    logger.debug("Processing shared Albums...")
    let sharedAlbums = try self.photokit.getSharedAlbums()
    for sharedAlbum in sharedAlbums {
      let albumUpsertRes = try self.exporterDB.upsertAlbum(
        album: ExportedAlbum.fromPhotokitAlbum(album: sharedAlbum)
      )
      switch albumUpsertRes {
      case .insert: albumInsertedCnt += 1
      case .update: albumUpdatedCnt += 1
      case .nochange: albumUnchangedCnt += 1
      }
    }

    logger.info("Folder and Album export complete in \(timeProvider.secondsPassedSince(startDate))s")
    return rootFolderResult.copy(
      albumInserted: rootFolderResult.albumInserted + albumInsertedCnt,
      albumUpdated: rootFolderResult.albumUpdated + albumUpdatedCnt,
      albumUnchanged: rootFolderResult.albumUnchanged + albumUnchangedCnt,
    )
  }

  private func processPhotokitFolder(folder: PhotokitFolder) throws -> CollectionExportResult {
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
    let folderUpsertRes = try self.exporterDB.upsertFolder(folder: exportedFolder)
    switch folderUpsertRes {
    case .insert: folderInsertedCnt += 1
    case .update: folderUpdatedCnt += 1
    case .nochange: folderUnchangedCnt += 1
    }

    for album in folder.albums {
      let albumUpsertRes = try self.exporterDB.upsertAlbum(album: ExportedAlbum.fromPhotokitAlbum(album: album))
      switch albumUpsertRes {
      case .insert: albumInsertedCnt += 1
      case .update: albumUpdatedCnt += 1
      case .nochange: albumUnchangedCnt += 1
      }
    }

    for subfolder in folder.subfolders {
      let subfolderRes = try processPhotokitFolder(folder: subfolder)
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
