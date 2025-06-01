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

@Suite("File Helper tests")
struct FileHelperTests {
  @Test("Path for Date and Location", arguments: [
    ("2025-04-15 10:30:05", Optional<String>.none, Optional<String>.none, "2025/2025-04"),
    ("2025-04-15 10:30:05", "Spain", Optional<String>.none, "2025/2025-04-spain"),
    ("2025-04-15 10:30:05", "Spain", "Dénia", "2025/2025-04-spain-denia"),
    ("2025-04-15 10:30:05", Optional<String>.none, "Dénia", "2025/2025-04-denia"),
  ])
  func pathForDateAndLocation(
    _ dateStrOpt: String,
    _ countryOpt: String?,
    _ cityOpt: String?,
    _ out: String
  ) {
    let dateOpt = TestHelpers.dateFromStr(dateStrOpt)
    let res = FileHelper.pathForDateAndLocation(dateOpt: dateOpt, countryOpt: countryOpt, cityOpt: cityOpt)
    #expect(res == out)
  }

  @Test("Filename with Date and Edited", arguments: [
    ("IMG004.jpg", "2025-04-15 10:30:05", false, "20250415103005-img004.jpg"),
    ("IMG004.jpg", "2025-04-15 10:30:05", true, "20250415103005-img004_edited.jpg"),
    ("Peter's awesome image-1.jpg", "2025-04-15 10:30:05", false, "20250415103005-peters_awesome_image1.jpg"),
  ])
  func filenameWithDateAndEdited(
    _ fileName: String,
    _ dateStrOpt: String?,
    _ isEdited: Bool,
    _ out: String
  ) {
    let dateOpt = TestHelpers.dateFromStr(dateStrOpt)
    let res = FileHelper.filenameWithDateAndEdited(originalFileName: fileName, dateOpt: dateOpt, isEdited: isEdited)
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

@Suite("Date Helper tests")
struct DateHelperTests {
  @Test("Safe Equals", arguments: [
    (Date(timeIntervalSince1970: 1269099904), Date(timeIntervalSince1970: 1269099904), true),
    (Date(timeIntervalSince1970: 1269099904.123), Date(timeIntervalSince1970: 1269099904.456), true),
    (nil as Date?, Date(timeIntervalSince1970: 1269099904), false),
    (Date(timeIntervalSince1970: 1269099904), nil as Date?, false),
    (nil as Date?, nil as Date?, true),
  ])
  func secondsEquals(
    _ date1: Date?,
    _ date2: Date?,
    _ result: Bool,
  ) {
    #expect(DateHelper.secondsEquals(date1, date2) == result)
  }

  @Test("Get year string", arguments: [
    (TestHelpers.dateFromStr("2025-03-15 12:00:00"), "2025"),
    (nil as Date?, "0000"),
  ])
  func getYearStr(_ date: Date?, _ out: String) {
    #expect(DateHelper.getYearStr(date) == out)
  }

  @Test("Get month string", arguments: [
    (TestHelpers.dateFromStr("2025-03-15 12:00:00"), "03"),
    (TestHelpers.dateFromStr("2025-12-15 12:00:00"), "12"),
    (nil as Date?, "00"),
  ])
  func getMonthStr(_ date: Date?, _ out: String) {
    #expect(DateHelper.getMonthStr(date) == out)
  }

  @Test("Get year-month string", arguments: [
    (TestHelpers.dateFromStr("2025-03-15 12:00:00"), "2025-03"),
    (TestHelpers.dateFromStr("2025-12-15 12:00:00"), "2025-12"),
    (nil as Date?, "0000-00"),
  ])
  func getYearMonthStr(_ date: Date?, _ out: String) {
    #expect(DateHelper.getYearMonthStr(date) == out)
  }
}
