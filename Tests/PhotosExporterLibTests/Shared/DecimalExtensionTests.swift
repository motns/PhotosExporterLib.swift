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

@Suite("DecimalExtension tests")
struct DecimalExtensionTests {
  @Test("Rounded", arguments: [
    ("100", 6, "100"),
    ("100.25", 6, "100.25"),
    ("100.123456789", 6, "100.123457"),
    ("100.123456", 6, "100.123456"),
    ("-100.1234562", 6, "-100.123456"),
    ("-0.16017799999999995904", 6, "-0.160178"),
  ])
  func rounded(
    _ num: String,
    _ scale: Int,
    _ result: String,
  ) {
    #expect(Decimal(string: num)!.rounded(scale: scale) == Decimal(string: result)!)
  }
}
