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

struct TestHelpers {
  static func dateFromStr(_ strOpt: String?) -> Date? {
    let dateOpt: Date?
    if let str = strOpt, str != "" {
      let dateFormatter = DateFormatter()
      dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
      dateOpt = dateFormatter.date(from: str)
    } else {
      dateOpt = nil
    }

    return dateOpt
  }

  static func createTestDir() throws -> URL {
    let testDir = URL(filePath: "/tmp").appending(path: UUID().uuidString)

    var isDirectory: ObjCBool = false
    if !(FileManager.default.fileExists(
      atPath: testDir.path(percentEncoded: false),
      isDirectory: &isDirectory
    ) && isDirectory.boolValue) {
      try FileManager.default.createDirectory(
        atPath: testDir.path(percentEncoded: false),
        withIntermediateDirectories: true,
        attributes: nil
      )
    }

    return testDir
  }
}
