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
import Testing
@testable import PhotosExporterLib

@Suite("FileHelper tests")
struct FileHelperTests {
  @Test("Path for Date and Location", arguments: [
    ("2025-04-15 10:30:05", Optional<String>.none, Optional<String>.none, "2025/2025-04"),
    ("2025-04-15 10:30:05", "Spain", Optional<String>.none, "2025/2025-04-spain"),
    ("2025-04-15 10:30:05", "Spain", "Dénia", "2025/2025-04-spain-denia"),
    ("2025-04-15 10:30:05", Optional<String>.none, "Dénia", "2025/2025-04-denia"),
  ])
  func pathForDateAndLocation(
    _ dateStr: String,
    _ country: String?,
    _ city: String?,
    _ out: String
  ) {
    let date = TestHelpers.dateFromStr(dateStr)
    let res = FileHelper.pathForDateAndLocation(date: date, country: country, city: city)
    #expect(res == out)
  }

  @Test("Normalise for Path", arguments: [
    ("London", "london"),
    ("Dénia", "denia"),
    ("United Kingdom", "united_kingdom"),
    ("Saint John's Wood", "saint_johns_wood"),
  ])
  func normaliseForPath(_ input: String, _ out: String) {
    #expect(FileHelper.normaliseForPath(input) == out)
  }
}
