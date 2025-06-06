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

@Suite("List Diff Test")
struct ListDiffTest {
  @Test("String Conversion")
  func stringConversion() {
    let diffStr = "\(Diff.getDiff([1, 2, 5], [1, 3]))"
    let expected =
      "different(ListDiff("
      + "[1]changed: SingleValueDiff(left: 2, right: 3), "
      + "[2]removed: 5))"
    #expect(diffStr == expected)

    let diffStr2 = "\(Diff.getDiff([1, 2], [1, 2, 3]))"
    let expected2 = "different(ListDiff([2]added: 3))"
    #expect(diffStr2 == expected2)
  }

  @Test("Pretty String Conversion")
  func prettyStringConversion() {
    let diffStr = Diff.getDiff([1, 2, 5], [1, 3]).prettyDescription
    let expected = """
    ListDiff:
      Changed at 1:
        Left: 2
        Right: 3
      Removed at 2:
        5
    """
    #expect(diffStr == expected)

    let diffStr2 = Diff.getDiff([1, 2], [1, 2, 3]).prettyDescription
    let expected2 = """
    ListDiff:
      Added at 2:
        3
    """
    #expect(diffStr2 == expected2)
  }
}
