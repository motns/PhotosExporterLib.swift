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

@Suite("Set Diff Test")
struct SetDiffTest {
  @Test("String Conversion")
  func stringConversion() {
    let diffStr = "\(Diff.getDiff(Set([1, 2, 3]), Set([1, 2, 4])))"
    let expected =
    "different(SetDiff(onlyInLeft: [3], onlyInRight: [4]))"
    #expect(diffStr == expected)
  }

  @Test("Pretty String Conversion")
  func prettyStringConversion() {
    let diffStr = Diff.getDiff(Set([1, 2, 3]), Set([1, 2, 4])).prettyDescription
    let expected = """
    SetDiff:
      Only in Left:
        3
      Only in Right:
        4
    """
    #expect(diffStr == expected)
  }
}
