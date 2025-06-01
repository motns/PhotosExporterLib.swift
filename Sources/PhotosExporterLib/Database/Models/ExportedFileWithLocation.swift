import Foundation
import GRDB

// Used for querying only - doesn't map to a database table
struct ExportedFileWithLocation: Decodable, FetchableRecord, Equatable {
  let exportedFile: ExportedFile
  let createdAt: Date?
  let country: String
  let city: String?

  enum CodingKeys: String, CodingKey {
    case exportedFile, country, city
    case createdAt = "created_at"
  }
}
