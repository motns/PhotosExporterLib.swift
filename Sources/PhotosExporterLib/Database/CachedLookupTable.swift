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

final class CachedLookupTable {
  private var cache = [String: Int64]()
  private let exporterDB: ExporterDB
  private let logger: ClassLogger
  private let table: LookupTable

  init(
    table: LookupTable,
    exporterDB: ExporterDB,
    logger: Logger
  ) {
    self.table = table
    self.exporterDB = exporterDB
    self.logger = ClassLogger(
      className: "CachedLookupTable",
      logger: logger,
      metadata: [
        "table": "\(table.rawValue)"
      ]
    )
  }

  func getIdByName(name: String) throws -> Int64 {
    self.logger.debug("Getting ID for name", ["name": "\(name)"])

    if let id = cache[name] {
      self.logger.trace("ID for name found in cache", [
        "name": "\(name)",
        "id": "\(id)",
      ])
      return id
    } else {
      self.logger.trace("ID for name not in cache - loading from DB...", ["name": "\(name)"])
      do {
        let id = try exporterDB.getLookupTableIdByName(table: table, name: name)
        self.logger.trace("ID for name loaded from DB", [
          "name": "\(name)",
          "id": "\(id)",
        ])
        cache[name] = id
        return id
      } catch {
        throw error
      }
    }
  }
}

enum LookupTable: String {
  case country, city
}
