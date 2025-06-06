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
import Testing
@testable import PhotosExporterLib

@Suite("Exported File Tests")
struct ExportedFileTests {
  // swiftlint:disable:next large_tuple
  static let args: [(String?, Int64, FileType?, String, String)] = [
    ("2025-04-15 10:30:05", 2059074, FileType.originalImage, "IMG004.jpg", "20250415103005-2059074-img004.jpg"),
    ("2025-04-15 10:30:05", 2059074, FileType.originalImage, "IMG004.JPG", "20250415103005-2059074-img004.jpg"),
    ("2025-04-15 10:30:05", 2059074, FileType.editedImage, "IMG004.jpg", "20250415103005-2059074-img004_edited.jpg"),
    (nil, 2059074, FileType.originalImage, "IMG004.jpg", "00000000000000-2059074-img004.jpg"),
    ("2025-04-15 10:30:05", 2059074, nil, "IMG004.jpg", "20250415103005-2059074-img004.jpg"),
  ]

  // Swift fails to infer the type when used here, and won't accept type casting either,
  // so our only option was to separate it out into a type attribute above...
  @Test("Generate ID", arguments: ExportedFileTests.args)
  func generateId(
    _ dateStr: String?,
    _ fileSize: Int64,
    _ fileType: FileType?,
    _ originalFileName: String,
    _ out: String,
  ) {
    let res = ExportedFile.generateId(
      assetCreatedAt: TestHelpers.dateFromStr(dateStr),
      fileSize: fileSize,
      fileType: fileType,
      originalFileName: originalFileName
    )
    #expect(res == out)
  }
}
