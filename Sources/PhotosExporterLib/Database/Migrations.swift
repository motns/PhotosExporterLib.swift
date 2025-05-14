import Foundation
import GRDB
import Logging

struct Migrations {
  private var migrator: DatabaseMigrator
  private let dbQueue: DatabaseQueue
  private let logger: ClassLogger

  init(
    dbQueue: DatabaseQueue,
    logger: Logger
  ) throws {
    self.migrator = DatabaseMigrator()
    self.dbQueue = dbQueue
    self.logger = ClassLogger(logger: logger, className: "Migrations")

    LookupTablesMigration.register(&migrator)
    MainTablesInitialMigration.register(&migrator)
  }

  func runMigrations() throws {
    try migrator.migrate(dbQueue)
  }
}

private protocol MigrationDef {
  static func register(_ migrator: inout DatabaseMigrator)
}

private struct LookupTablesMigration: MigrationDef {
  // swiftlint:disable:next function_body_length
  static func register(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration("Lookup tables") { db in
      try db.create(table: "country") { table in
        table.primaryKey("id", .integer)
        table.column("name", .text).notNull().unique()
      }

      try db.create(table: "city") { table in
        table.primaryKey("id", .integer)
        table.column("name", .text).notNull().unique()
      }

      try db.create(table: "asset_type") { table in
        table.primaryKey("id", .integer)
        table.column("name", .text).notNull().unique()
      }

      try db.execute(literal: """
      INSERT INTO asset_type (id, name)
      VALUES (1, \("image")),
      (2, \("video")),
      (3, \("audio"))
      """)

      try db.create(table: "file_type") { table in
        table.primaryKey("id", .integer)
        table.column("name", .text).notNull().unique()
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

      try db.create(table: "album_type") { table in
        table.primaryKey("id", .integer)
        table.column("name", .text).notNull().unique()
      }

      try db.execute(literal: """
      INSERT INTO album_type (id, name)
      VALUES (1, \("user")),
      (2, \("shared"))
      """)

      try db.create(table: "asset_library") { table in
        table.primaryKey("id", .integer)
        table.column("name", .text).notNull().unique()
      }

      try db.execute(literal: """
      INSERT INTO asset_library (id, name)
      VALUES (1, \("personal_library")),
      (2, \("shared_library")),
      (3, \("shared_album"))
      """)
    }
  }
}

private struct MainTablesInitialMigration: MigrationDef {
  static func register(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration("Main tables - initial") { db in
      try db.create(table: "asset") { table in
        table.primaryKey("id", .text).notNull()
        table.column("asset_type_id", .integer).notNull().references("asset_type")
        table.column("asset_library_id", .integer).notNull().references("asset_library")
        table.column("created_at", .datetime)
        table.column("updated_at", .datetime)
        table.column("imported_at", .datetime).notNull()
        table.column("is_favourite", .boolean).notNull()
        table.column("geo_lat", .double)
        table.column("geo_long", .double)
        table.column("country_id", .integer).references("country")
        table.column("city_id", .integer).references("city")
        table.column("is_deleted", .boolean).notNull()
        table.column("deleted_at", .datetime)
      }

      try db.create(table: "file") { table in
        table.column("asset_id", .text).notNull().references("asset")
        table.column("file_type_id", .integer).notNull().references("file_type")
        table.column("original_file_name", .text).notNull()
        table.primaryKey(["asset_id", "file_type_id", "original_file_name"])
        table.column("imported_at", .datetime).notNull()
        table.column("imported_file_dir", .text).notNull()
        table.column("imported_file_name", .text).notNull()
        table.column("was_copied", .boolean).notNull()
        table.column("is_deleted", .boolean).notNull()
        table.column("deleted_at", .datetime)
      }

      try db.create(table: "album_folder") { table in
        table.primaryKey("id", .text).notNull()
        table.column("name", .text).notNull()
        table.column("parent_id", .text).references("album_folder")
      }

      try db.create(indexOn: "album_folder", columns: ["parent_id"])

      try db.create(table: "album") { table in
        table.primaryKey("id", .text).notNull()
        table.column("album_type_id", .integer).notNull().references("album_type")
        table.column("album_folder_id", .text).notNull().references("album_folder")
        table.column("name", .text).notNull()
        table.column("asset_ids", .jsonb).notNull()
      }

      try db.create(indexOn: "album", columns: ["album_folder_id"])
    }
  }
}
