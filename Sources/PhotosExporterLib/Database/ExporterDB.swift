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
import GRDB

/*
Used to access our local DB containing a copy of information from the Photos DB
*/
// swiftlint:disable file_length
struct ExporterDB {
  private let dbQueue: DatabaseQueue
  private let logger: ClassLogger

  public enum UpsertResult {
    case insert, update, nochange

    func merge(_ other: UpsertResult) -> UpsertResult {
      return (self == .nochange) ? other : self
    }
  }

  public enum InsertResult {
    case insert, duplicate
  }

  public enum Error: Swift.Error {
    case connectionFailed(String)
    case missingMigrationBundle(String)
    case migrationFailed(String)
    case assetConversionFailed(String)
    case unsupportedAlbumType(String)
  }

  init(
    exportDBPath: URL,
    logger: Logger,
  ) throws {
    self.logger = ClassLogger(className: "ExporterDB", logger: logger)

    do {
      self.logger.debug("Connecting to Export DB...")
      dbQueue = try DatabaseQueue(path: exportDBPath.path(percentEncoded: false))
      self.logger.debug("Connected to Export DB")
    } catch {
      self.logger.critical("Failed to connect to ExporterDB")
      throw Error.connectionFailed("\(error)")
    }

    do {
      self.logger.debug("Initialising Migrations...")
      let migrations = try Migrations(dbQueue: dbQueue, logger: logger)
      try migrations.runMigrations()
    } catch {
      self.logger.critical("Failed to migrate ExporterDB", [
        "error": "\(error)"
      ])
      throw Error.migrationFailed("\(error)")
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

  func countAssets() throws -> Int {
    return try dbQueue.read { db in
      try ExportedAsset.fetchCount(db)
    }
  }

  func getAssetIdSet() throws -> Set<String> {
    return try dbQueue.read { db in
      try String.fetchSet(
        db,
        sql: """
        SELECT id
        FROM asset
        WHERE is_deleted = false
        """
      )
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

  func getFilesWithLocation() throws -> [ExportedFileWithLocation] {
    try dbQueue.read { db in
      try ExportedFileWithLocation.fetchAll(
        db,
        sql: """
        SELECT
          file.*,
          file_asset.created_at,
          country.name As country,
          city.name As city
        FROM file
          LEFT JOIN country ON country.id = file.country_id
          LEFT JOIN city ON city.id = file.city_id
          JOIN (
            SELECT
              asset_file.file_id,
              MIN(asset.created_at) AS created_at
            FROM asset_file
              JOIN asset ON asset.id = asset_file.asset_id
            GROUP BY asset_file.file_id
          ) AS file_asset ON file_asset.file_id = file.id
        WHERE
          file.country_id IS NOT NULL
        """
      )
    }
  }

  func getFilesWithScore(threshold: Int64) throws -> [ExportedFileWithScore] {
    try dbQueue.read { db in
      try ExportedFileWithScore.fetchAll(
        db,
        sql: """
        SELECT
          file.*,
          file_asset.score
        FROM file
          JOIN (
            SELECT
              asset_file.file_id,
              MAX(asset.aesthetic_score) AS score
            FROM asset_file
              JOIN asset ON asset.id = asset_file.asset_id
            GROUP BY asset_file.file_id
          ) AS file_asset ON file_asset.file_id = file.id
        WHERE
          ? <= file_asset.score
        """,
        arguments: [threshold]
      )
    }
  }

  func countFiles() throws -> Int {
    return try dbQueue.read { db in
      try ExportedFile.fetchCount(db)
    }
  }

  func sumFileSizes() throws -> Int64? {
    return try dbQueue.read { db in
      return try Int64.fetchOne(
        db,
        sql: """
        SELECT
          SUM(file_size)
        FROM file
        """
      )
    }
  }

  func getFileIdSet() throws -> Set<String> {
    return try dbQueue.read { db in
      try String.fetchSet(
        db,
        sql: """
        SELECT id
        FROM file
        WHERE NOT EXISTS(
          SELECT 1
          FROM asset_file
          WHERE
            asset_file.file_id = file.id
            AND is_deleted = true
        )
        """
      )
    }
  }

  // Orphaned Files are the ones which are no longer linked
  // to any assets via Asset Files
  func getOrphanedFiles() throws -> [ExportedFile] {
    logger.debug("Getting orphaned Files...")

    return try dbQueue.read { db in
      try ExportedFile.fetchAll(
        db,
        sql: """
        SELECT
          file.*
        FROM file
        WHERE NOT EXISTS (
          SELECT 1
          FROM asset_file
          WHERE file_id = file.id
        )
        """
      )
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

  func countFolders() throws -> Int {
    return try dbQueue.read { db in
      try ExportedFolder.fetchCount(db)
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

  func countAlbums() throws -> Int {
    return try dbQueue.read { db in
      try ExportedAlbum.fetchCount(db)
    }
  }

  func getExportResultHistoryEntry(id: String) throws -> ExportResultHistoryEntry? {
    return try dbQueue.read { db in
      try ExportResultHistoryEntry.fetchOne(db, id: id)
    }
  }

  func getLatestExportResultHistoryEntry() throws -> ExportResultHistoryEntry? {
    return try dbQueue.read { db in
      try ExportResultHistoryEntry
        .order(\.createdAt.desc)
        .limit(1)
        .fetchOne(db)
    }
  }

  func getExportResultHistoryEntries(limit: Int = 10, offset: Int? = nil) throws -> [ExportResultHistoryEntry] {
    return try dbQueue.read { db in
      try ExportResultHistoryEntry
        .order(\.createdAt.desc)
        .limit(limit, offset: offset)
        .fetchAll(db)
    }
  }
}

// - MARK: Writing
extension ExporterDB {
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
        let updated = curr.updated(from: asset)
        try updated.update(db)

        logger.trace("Asset updated", [
          "id": "\(asset.id)",
          "diff": "\(Diff.getDiff(curr, updated))",
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
        try updated.update(db)

        logger.trace("File updated", [
          "id": "\(updated.id)",
          "diff": "\(Diff.getDiff(curr, updated))",
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
        let updated = curr.updated(assetFile)
        try updated.update(db)

        logger.trace("Asset File link updated", [
          "asset_id": "\(assetFile.assetId)",
          "file_id": "\(assetFile.fileId)",
          "diff": "\(Diff.getDiff(curr, updated))",
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
        let updated = curr.updated(folder)
        try updated.update(db)

        logger.trace("Folder updated", [
          "id": "\(folder.id)",
          "diff": "\(Diff.getDiff(curr, updated))",
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
        let updated = curr.updated(album)
        try updated.update(db)

        logger.trace("Album updated", [
          "id": "\(album.id)",
          "diff": "\(Diff.getDiff(curr, updated))",
        ])
        return UpsertResult.update
      } else {
        try album.insert(db)
        logger.trace("New Album inserted", loggerMetadata)
        return UpsertResult.insert
      }
    }
  }

  func markAssetAsDeleted(id: String, now: Date? = nil) throws {
    logger.debug("Marking Asset as deleted...", [
      "id": "\(id)",
      "now": "\(String(describing: now))",
    ])
    return try dbQueue.write { db in
      try ExportedAsset
        .filter(id: id)
        .updateAll(db) {
          [
            $0.isDeleted.set(to: true),
            $0.deletedAt.set(to: now ?? Date()),
          ]
        }
    }
  }

  func deleteExpiredAssets(cutoffDate: Date) throws -> (Int, Int) {
    logger.debug("Deleting expired Assets...")
    return try dbQueue.write { db in
      let fileCnt = try ExportedAssetFile
        .filter(
          sql: """
          asset_id IN(
            SELECT id
            FROM asset
            WHERE
              is_deleted = true
              AND deleted_at < ?
          )
          """,
          arguments: [cutoffDate]
        ).deleteAll(db)

      let assetCnt = try ExportedAsset
        .filter {
          $0.isDeleted == true
          && $0.deletedAt < cutoffDate
        }.deleteAll(db)

      return (assetCnt, fileCnt)
    }
  }

  func markFileAsCopied(id: String) throws {
    logger.debug("Marking File as copied...", [
      "id": "\(id)"
    ])
    _ = try dbQueue.write { db in
      try ExportedFile
        .filter(id: id)
        .updateAll(db) {
          $0.wasCopied.set(to: true)
        }
    }
  }

  func markFileAsDeleted(id: String, now: Date? = nil) throws {
    logger.debug("Marking File as deleted...", [
      "id": "\(id)",
      "now": "\(String(describing: now))",
    ])
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

  func deleteExpiredAssetFiles(cutoffDate: Date) throws -> Int {
    logger.debug("Deleting expired Asset Files...")
    return try dbQueue.write { db in
      return try ExportedAssetFile
        .filter {
          $0.isDeleted == true
          && $0.deletedAt < cutoffDate
        }.deleteAll(db)
    }
  }

  func deleteFile(id: String) throws -> Bool {
    logger.debug("Deleting File with ID...", [
      "id": "\(id)",
    ])
    return try dbQueue.write { db in
      try ExportedFile.deleteOne(db, id: id)
    }
  }

  func insertExportResultHistoryEntry(entry: ExportResultHistoryEntry) throws {
    try dbQueue.write { db in
      try entry.insert(db)
    }
  }
}
