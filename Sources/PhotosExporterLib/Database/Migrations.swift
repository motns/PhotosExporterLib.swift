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
    self.logger = ClassLogger(className: "Migrations", logger: logger)

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
      try ExportedAsset.createTable(db)
      try ExportedFile.createTable(db)
      try ExportedAssetFile.createTable(db)
      try ExportedFolder.createTable(db)
      try ExportedAlbum.createTable(db)
      try ExportResultHistoryEntry.createTable(db)
    }
  }
}
