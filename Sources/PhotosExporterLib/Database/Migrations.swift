import Foundation
import GRDB
import Logging

actor Migrations {
  private var migrator: DatabaseMigrator
  private let dbQueue: DatabaseQueue
  private let logger: ClassLogger

  init(
    dbQueue: DatabaseQueue,
    logger: Logger
  ) async throws {
    self.migrator = DatabaseMigrator()
    self.dbQueue = dbQueue
    self.logger = ClassLogger(logger: logger, className: "Migrations")

    try registerMigrations()
  }

  func runMigrations() throws {
    try migrator.migrate(dbQueue)
  }

  private func registerMigrations() throws {
    migrator.registerMigration("Lookup tables") { db in
      try db.create(table: "country") { t in
        t.primaryKey("id", .integer)
        t.column("name", .text).notNull().unique()
      }

      try db.create(table: "city") { t in
        t.primaryKey("id", .integer)
        t.column("name", .text).notNull().unique()
      }

      try db.create(table: "asset_type") { t in
        t.primaryKey("id", .integer)
        t.column("name", .text).notNull().unique()
      }

      try db.execute(literal: """
      INSERT INTO asset_type (id, name)
      VALUES (1, \("image")),
      (2, \("video")),
      (3, \("audio"))
      """)

      try db.create(table: "file_type") { t in
        t.primaryKey("id", .integer)
        t.column("name", .text).notNull().unique()
      }

      try db.execute(literal: """
      INSERT INTO file_type (id, name)
      VALUES (1, \("original_image")),
      (2, \("original_video")),
      (3, \("original_audio")),
      (4, \("original_live_video")),
      (5, \("edited_image")),
      (6, \("edited_video")),
      (7, \("edited_live_video"))
      """)

      try db.create(table: "album_type") { t in
        t.primaryKey("id", .integer)
        t.column("name", .text).notNull().unique()
      }

      try db.execute(literal: """
      INSERT INTO album_type (id, name)
      VALUES (1, \("user")),
      (2, \("shared"))
      """)

      try db.create(table: "asset_library") { t in
        t.primaryKey("id", .integer)
        t.column("name", .text).notNull().unique()
      }

      try db.execute(literal: """
      INSERT INTO asset_library (id, name)
      VALUES (1, \("personal_library")),
      (2, \("shared_library")),
      (3, \("shared_album"))
      """)
    }

    migrator.registerMigration("Main tables - initial") { db in
      try db.create(table: "asset") { t in
        t.primaryKey("id", .text).notNull()
        t.column("asset_type_id", .integer).notNull().references("asset_type")
        t.column("asset_library_id", .integer).notNull().references("asset_library")
        t.column("created_at", .datetime)
        t.column("updated_at", .datetime)
        t.column("imported_at", .datetime).notNull()
        t.column("is_favourite", .boolean).notNull()
        t.column("geo_lat", .double)
        t.column("geo_long", .double)
        t.column("country_id", .integer).references("country")
        t.column("city_id", .integer).references("city")
        t.column("is_deleted", .boolean).notNull()
        t.column("deleted_at", .datetime)
      }

      try db.create(table: "file") { t in 
        t.column("asset_id", .text).notNull().references("asset")
        t.column("file_type_id", .integer).notNull().references("file_type")
        t.column("original_file_name", .text).notNull()
        t.primaryKey(["asset_id", "file_type_id", "original_file_name"])
        t.column("imported_at", .datetime).notNull()
        t.column("imported_file_dir", .text).notNull()
        t.column("imported_file_name", .text).notNull()
        t.column("was_copied", .boolean).notNull()
        t.column("is_deleted", .boolean).notNull()
        t.column("deleted_at", .datetime)
      }

      try db.create(table: "album_folder") { t in
        t.primaryKey("id", .text).notNull()
        t.column("name", .text).notNull()
        t.column("parent_id", .text).references("album_folder")
      }

      try db.create(indexOn: "album_folder", columns: ["parent_id"])

      try db.create(table: "album") { t in
        t.primaryKey("id", .text).notNull()
        t.column("album_type_id", .integer).notNull().references("album_type")
        t.column("album_folder_id", .text).notNull().references("album_folder")
        t.column("name", .text).notNull()
        t.column("asset_ids", .jsonb).notNull()
      }

      try db.create(indexOn: "album", columns: ["album_folder_id"])
    }
  }
}