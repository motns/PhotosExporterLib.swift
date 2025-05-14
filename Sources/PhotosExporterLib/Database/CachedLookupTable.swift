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
      logger: logger,
      className: "CachedLookupTable",
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
