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
    dateOpt: Date?,
    countryOpt: String? = nil,
    cityOpt: String? = nil
  ) -> String {
    let calendar = Calendar.current
    let year: String
    let month: String

    if let date = dateOpt {
      year = String(calendar.component(.year, from: date))
      month = String(format: "%02d", calendar.component(.month, from: date))
    } else {
      year = "0000"
      month = "00"
    }

    let countryComponent = switch countryOpt {
    case .some(let country) where country != "": "-\(normaliseForPath(country))"
    default: ""
    }

    let cityComponent = switch cityOpt {
    case .some(let city) where city != "": "-\(normaliseForPath(city))"
    default: ""
    }

    return "\(year)/\(year)-\(month)\(countryComponent)\(cityComponent)"
  }

  public static func filenameWithDateAndEdited(originalFileName: String, dateOpt: Date?, isEdited: Bool) -> String {
      let prefix: String
      if let date = dateOpt {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        prefix = formatter.string(from: date)
      } else {
        prefix = "00000000000000"
      }

      let fileURL = URL(filePath: originalFileName)
      let name = normaliseForPath(fileURL.deletingPathExtension().lastPathComponent)
      let ext = fileURL.pathExtension
      let suffix = isEdited ? "_edited" : ""

      return "\(prefix)-\(name)\(suffix).\(ext)"
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
