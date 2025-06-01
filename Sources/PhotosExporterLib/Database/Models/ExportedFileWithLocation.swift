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
