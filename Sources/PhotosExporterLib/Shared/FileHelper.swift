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

struct FileHelper {
  public static func pathForDateAndLocation(
    date: Date?,
    country: String? = nil,
    city: String? = nil
  ) -> String {
    let calendar = Calendar.current
    let year: String
    let month: String

    if let date = date {
      year = String(calendar.component(.year, from: date))
      month = String(format: "%02d", calendar.component(.month, from: date))
    } else {
      year = "0000"
      month = "00"
    }

    let countryComponent = switch country {
    case .some(let country) where country != "": "-\(normaliseForPath(country))"
    default: ""
    }

    let cityComponent = switch city {
    case .some(let city) where city != "": "-\(normaliseForPath(city))"
    default: ""
    }

    return "\(year)/\(year)-\(month)\(countryComponent)\(cityComponent)"
  }

  public static func normaliseForPath(_ str: String) -> String {
    return str.folding(options: .diacriticInsensitive, locale: .current)
              .replacingOccurrences(of: "\\s+", with: "_", options: .regularExpression)
              .replacingOccurrences(of: "[^\\w\\d]+", with: "", options: .regularExpression)
              .lowercased()
  }
}

enum FileHelperError: Error {
  case fileExistsAtDirectoryPath(String)
}
