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

  public static func createDirectory(url: URL) throws -> Bool {
    return try createDirectory(path: url.path(percentEncoded: false))
  }

  public static func createDirectory(path: String) throws -> Bool {
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(
      atPath: path,
      isDirectory: &isDirectory
    ) && !isDirectory.boolValue {
      throw FileHelperError.fileExistsAtDirectoryPath(path)
    }

    guard !FileManager.default.fileExists(atPath: path) else {
      return false
    }

    try FileManager.default.createDirectory(
      atPath: path,
      withIntermediateDirectories: true,
      attributes: nil
    )
    return true
  }
}

enum FileHelperError: Error {
  case fileExistsAtDirectoryPath(String)
}
