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

struct ExportedFolder: Codable, Equatable, Hashable {
  let id: String
  let name: String
  let parentId: String?

  enum CodingKeys: String, CodingKey {
    case id, name
    case parentId = "parent_id"
  }

  func needsUpdate(_ other: ExportedFolder) -> Bool {
    return self.name != other.name || self.parentId != other.parentId
  }

  func updated(_ other: ExportedFolder) -> ExportedFolder {
    return self.copy(
      name: other.name,
      parentId: other.parentId
    )
  }

  func copy(
    id: String? = nil,
    name: String? = nil,
    parentId: String?? = nil
  ) -> ExportedFolder {
    return ExportedFolder(
      id: id ?? self.id,
      name: name ?? self.name,
      parentId: parentId ?? self.parentId
    )
  }

  static func fromPhotokitFolder(
    folder: PhotokitFolder,
    parentId: String?,
  ) -> ExportedFolder {
    return ExportedFolder(
      id: folder.id,
      name: folder.title,
      parentId: parentId
    )
  }
}

extension ExportedFolder: Identifiable, TableRecord, PersistableRecord, FetchableRecord {
  static let databaseTableName = "album_folder"

  enum Columns {
    static let id = Column(CodingKeys.id)
    static let name = Column(CodingKeys.name)
    static let parentId = Column(CodingKeys.parentId)
  }

  static func createTable(_ db: Database) throws {
    try db.create(table: databaseTableName) { table in
      table.primaryKey("id", .text).notNull()
      table.column("name", .text).notNull()
      table.column("parent_id", .text).references("album_folder")
    }

    try db.create(indexOn: "album_folder", columns: ["parent_id"])
  }
}
