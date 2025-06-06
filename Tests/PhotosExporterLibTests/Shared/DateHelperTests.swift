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
import Foundation
@testable import PhotosExporterLib

@Suite("DateHelper tests")
struct DateHelperTests {
  @Test("Seconds Equals", arguments: [
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

  @Test("Truncate to seconds")
  func truncateToSeconds() {
    let date1 = Date(timeIntervalSince1970: 1269099904.978123)
    let date2 = Date(timeIntervalSince1970: 1269099904)
    #expect(DateHelper.truncateToSeconds(date1) == date2)
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
