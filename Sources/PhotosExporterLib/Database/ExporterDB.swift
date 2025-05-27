import Foundation
import Logging
import GRDB

/*
Used to access our local DB containing a copy of information from the Photos DB
*/
// swiftlint:disable file_length
struct ExporterDB {
  private let dbQueue: DatabaseQueue
  private let logger: ClassLogger

  init(
    exportDBPath: String,
    logger: Logger,
  ) throws {
    self.logger = ClassLogger(logger: logger, className: "ExporterDB")

    do {
      self.logger.debug("Connecting to Export DB...")
      dbQueue = try DatabaseQueue(path: exportDBPath)
      self.logger.debug("Connected to Export DB")
    } catch {
      self.logger.critical("Failed to connect to ExporterDB")
      throw ExporterDBError.connectionFailed("\(error)")
    }

    do {
      self.logger.debug("Initialising Migrations...")
      let migrations = try Migrations(dbQueue: dbQueue, logger: logger)
      try migrations.runMigrations()
    } catch {
      self.logger.critical("Failed to migrate ExporterDB", [
        "error": "\(error)"
      ])
      throw ExporterDBError.migrationFailed("\(error)")
    }
  }
}

// -- MARK: Reading
extension ExporterDB {
  func getLookupTableIdByName(table: LookupTable, name: String) throws -> Int64 {
    let loggerMetadata: Logger.Metadata = [
      "table": "\(table.rawValue)",
      "name": "\(name)",
    ]
    logger.debug("Getting ID for Lookup Table value...", loggerMetadata)

    return try dbQueue.write { db in
      let rowOpt = try Row.fetchOne(
        db,
        sql: "SELECT id FROM \(table.rawValue) WHERE name = ?",
        arguments: [name]
      )

      if let row: Row = rowOpt {
        let id: Int64 = row["id"]
        self.logger.trace(
          "Value already exists in Lookup Table",
          loggerMetadata.merging(["id": "\(id)"]) { $1 }
        )
        return id
      } else {
        try db.execute(sql: "INSERT INTO \(table.rawValue) (name) VALUES (?)", arguments: [name])
        let id = db.lastInsertedRowID
        self.logger.trace(
          "Inserted new value into Lookup Table",
          loggerMetadata.merging(["id": "\(id)"]) { $1 }
        )
        return id
      }
    }
  }

  func getAsset(id: String) throws -> ExportedAsset? {
    logger.debug("Retrieving Asset", [
      "asset_id": "\(id)"
    ])

    return try dbQueue.read { db in
      try ExportedAsset.fetchOne(db, id: id)
    }
  }

  func getAllAssets() throws -> [ExportedAsset] {
    return try dbQueue.read { db in
      try ExportedAsset.fetchAll(db)
    }
  }

  func getFile(id: String) throws -> ExportedFile? {
    logger.debug("Retrieving File", ["id": "\(id)"])

    return try dbQueue.read { db in
      try ExportedFile.fetchOne(db, id: id)
    }
  }

  func getAllFiles() throws -> [ExportedFile] {
    return try dbQueue.read { db in
      try ExportedFile.fetchAll(db)
    }
  }

  func getAssetFile(assetId: String, fileId: String) throws -> ExportedAssetFile? {
    logger.debug("Retrieving Asset File", [
      "asset_id": "\(assetId)",
      "file_id": "\(fileId)",
    ])

    return try dbQueue.read { db in
      try ExportedAssetFile.filter {
        $0.assetId == assetId
        && $0.fileId == fileId
      }.fetchOne(db)
    }
  }

  func getAllAssetFiles() throws -> [ExportedAssetFile] {
    return try dbQueue.read { db in
      try ExportedAssetFile.fetchAll(db)
    }
  }

  func getFolder(id: String) throws -> ExportedFolder? {
    logger.debug("Retrieving Folder", [
      "id": "\(id)"
    ])

    return try dbQueue.read { db in
      try ExportedFolder.fetchOne(db, id: id)
    }
  }

  func getAllFolders() throws -> [ExportedFolder] {
    return try dbQueue.read { db in
      try ExportedFolder.fetchAll(db)
    }
  }

  func getFoldersWithParent(parentId: String) throws -> [ExportedFolder] {
    logger.debug("Retrieving Folders with given Parent", [
      "parent_id": "\(parentId)"
    ])

    return try dbQueue.read { db in
      try ExportedFolder.filter(
        sql: "parent_id = ?",
        arguments: [parentId]
      ).fetchAll(db)
    }
  }

  func getAlbum(id: String) throws -> ExportedAlbum? {
    logger.debug("Retrieving Album", [
      "id": "\(id)"
    ])

    return try dbQueue.read { db in
      try ExportedAlbum.fetchOne(db, id: id)
    }
  }

  func getAlbumsInFolder(folderId: String) throws -> [ExportedAlbum] {
    logger.debug("Retrieving Albums in given Folder", [
      "folder_id": "\(folderId)"
    ])

    return try dbQueue.read { db in
      try ExportedAlbum.filter(
        sql: "album_folder_id = ?",
        arguments: [folderId]
      ).fetchAll(db)
    }
  }

  func getAllAlbums() throws -> [ExportedAlbum] {
    return try dbQueue.read { db in
      try ExportedAlbum.fetchAll(db)
    }
  }
}

// - MARK: Writing
extension ExporterDB {
  func markFileAsCopied(id: String) throws {
    _ = try dbQueue.write { db in
      try ExportedFile
        .filter(id: id)
        .updateAll(db) {
          $0.wasCopied.set(to: true)
        }
    }
  }

  func markFileAsDeleted(id: String, now: Date? = nil) throws {
    return try dbQueue.write { db in
      try ExportedAssetFile.filter {
        $0.fileId == id
      }.updateAll(db) {
        [
          $0.isDeleted.set(to: true),
          $0.deletedAt.set(to: now ?? Date()),
        ]
      }
    }
  }

  func getFilesWithAssetIdsToCopy() throws -> [ExportedFileWithAssetIds] {
    logger.debug("Getting Files to copy...")

    return try dbQueue.read { db in
      try ExportedFileWithAssetIds.fetchAll(
        db,
        sql: """
        SELECT
          file.*,
          asset_file_by_file.asset_ids
        FROM file
          JOIN (
            SELECT
              file_id,
              json_group_array(asset_id) As asset_ids,
              max(is_deleted) AS is_deleted
            FROM asset_file
            GROUP BY file_id
          ) AS asset_file_by_file ON asset_file_by_file.file_id = file.id
        WHERE
          file.was_copied = false
          AND asset_file_by_file.is_deleted = 0
        """
      )
    }
  }

  func getFilesForAlbum(albumId: String) throws -> [ExportedFile] {
    logger.debug("Getting Files for Album...", [
      "album_id": "\(albumId)"
    ])

    return try dbQueue.read { db in
      try ExportedFile.fetchAll(
        db,
        sql: """
        SELECT
          file.*
        FROM file
        WHERE file.id IN(
          SELECT file_id
          FROM asset_file
          WHERE asset_id IN(
            SELECT value
            FROM album
              JOIN json_each(album.asset_ids)
            WHERE album.id = ?
          )
        )
        """,
        arguments: [albumId]
      )
    }
  }

  func upsertAsset(asset: ExportedAsset, now: Date? = nil) throws -> UpsertResult {
    let loggerMetadata: Logger.Metadata = [
      "asset_id": "\(asset.id)"
    ]
    logger.debug("Upserting Asset...", loggerMetadata)

    return try dbQueue.write { db in
      if let curr = try ExportedAsset.fetchOne(db, id: asset.id) {
        guard curr.needsUpdate(asset) else {
          logger.trace("Asset hasn't changed - skipping", loggerMetadata)
          return UpsertResult.nochange
        }

        logger.trace("Asset changed - updating...", loggerMetadata)
        try curr.updated(from: asset).update(db)

        logger.trace("Asset updated", [
          "asset_id": "\(asset.id)",
          "is_favourite": "\(asset.isFavourite)",
          "geo_lat": "\(String(describing: asset.geoLat))",
          "geo_long": "\(String(describing: asset.geoLong))",
          "city_id": "\(String(describing: asset.cityId))",
          "country_id": "\(String(describing: asset.countryId))",
        ])

        return UpsertResult.update
      } else {
        try asset.insert(db)
        logger.trace("New Asset inserted", loggerMetadata)
        return UpsertResult.insert
      }
    }
  }

  func upsertFile(file: ExportedFile) throws -> UpsertResult {
    let loggerMetadata: Logger.Metadata = [
      "id": "\(file.id)",
    ]
    logger.debug("Upserting File...", loggerMetadata)

    return try dbQueue.write { db in
      let currOpt = try ExportedFile.fetchOne(db, id: file.id)

      if let curr = currOpt {
        logger.trace("File already exists in DB - checking for changes...", loggerMetadata)

        guard curr.needsUpdate(file) else {
          logger.trace("File hasn't changed - skipping", loggerMetadata)
          return UpsertResult.nochange
        }

        logger.trace("File changed - updating...", loggerMetadata)
        let updated = curr.updated(file)
        try curr.updated(file).update(db)

        logger.trace("File updated", [
          "id": "\(updated.id)",
          "imported_file_dir": "\(updated.importedFileDir)",
          "imported_file_name": "\(updated.importedFileName)",
          "file_size": "\(updated.fileSize)",
          "was_copied": "\(updated.wasCopied)",
        ])

        return UpsertResult.update
      } else {
        try file.insert(db)
        logger.trace("New File inserted", loggerMetadata)
        return UpsertResult.insert
      }
    }
  }

  func upsertAssetFile(assetFile: ExportedAssetFile) throws -> UpsertResult {
    let loggerMetadata: Logger.Metadata = [
      "asset_id": "\(assetFile.assetId)",
      "file_id": "\(assetFile.fileId)",
    ]
    logger.debug("Upserting Asset File link...", loggerMetadata)

    return try dbQueue.write { db in
      let currOpt = try ExportedAssetFile.filter {
        $0.assetId == assetFile.assetId
        && $0.fileId == assetFile.fileId
      }.fetchOne(db)

      if let curr = currOpt {
        logger.trace("Asset File link already exists in DB - checking for changes...", loggerMetadata)

        guard curr.needsUpdate(assetFile) else {
          logger.trace("Asset File link hasn't changed - skipping", loggerMetadata)
          return UpsertResult.nochange
        }

        logger.trace("Asset File link changed - updating...", loggerMetadata)
        try curr.updated(assetFile).update(db)

        logger.trace("Asset File link updated", [
          "asset_id": "\(assetFile.assetId)",
          "file_id": "\(assetFile.fileId)",
          "is_deleted": "\(assetFile.isDeleted)",
          "deleted_at": "\(String(describing: assetFile.deletedAt))",
        ])

        return UpsertResult.update
      } else {
        try assetFile.insert(db)
        logger.trace("New Asset File link inserted", loggerMetadata)
        return UpsertResult.insert
      }
    }
  }

  func upsertFolder(folder: ExportedFolder) throws -> UpsertResult {
    let loggerMetadata: Logger.Metadata = [
      "id": "\(folder.id)"
    ]
    logger.debug("Upserting Folder...", loggerMetadata)

    return try dbQueue.write { db in
      if let curr = try ExportedFolder.fetchOne(db, id: folder.id) {
        logger.trace("Folder already exists in DB - checking for changes...", loggerMetadata)

        guard curr.needsUpdate(folder) else {
          logger.trace("Folder hasn't changed - skipping", loggerMetadata)
          return UpsertResult.nochange
        }

        logger.trace("Folder changed - updating...", loggerMetadata)
        try curr.updated(folder).update(db)

        logger.trace("Folder updated", [
          "folder_id": "\(folder.id)",
          "folder_name": "\(folder.name)",
          "parent_id": "\(String(describing: folder.parentId))",
        ])
        return UpsertResult.update
      } else {
        try folder.insert(db)
        logger.trace("New Folder inserted", loggerMetadata)
        return UpsertResult.insert
      }
    }
  }

  func upsertAlbum(album: ExportedAlbum) throws -> UpsertResult {
    let loggerMetadata: Logger.Metadata = [
      "id": "\(album.id)",
      "name": "\(album.name)",
      "album_type": "\(album.albumType)",
    ]
    logger.debug("Upserting Album...", loggerMetadata)

    return try dbQueue.write { db in
      if let curr = try ExportedAlbum.fetchOne(db, id: album.id) {
        logger.trace("Album already exists in DB - checking for changes...", loggerMetadata)

        guard curr.needsUpdate(album) else {
          logger.trace("Album hasn't changed - skipping", loggerMetadata)
          return UpsertResult.nochange
        }

        logger.trace("Album changed - updating...", loggerMetadata)
        try curr.updated(album).update(db)
        return UpsertResult.update
      } else {
        try album.insert(db)
        logger.trace("New Album inserted", loggerMetadata)
        return UpsertResult.insert
      }
    }
  }
}

enum UpsertResult {
  case insert, update, nochange

  func merge(_ other: UpsertResult) -> UpsertResult {
    return (self == .nochange) ? other : self
  }
}

enum InsertResult {
  case insert, duplicate
}

enum ExporterDBError: Error {
  case connectionFailed(String)
  case missingMigrationBundle(String)
  case migrationFailed(String)
  case assetConversionFailed(String)
  case unsupportedAlbumType(String)
}
