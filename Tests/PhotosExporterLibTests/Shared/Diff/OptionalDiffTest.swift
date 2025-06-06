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

@Suite("Optional Diff Test")
struct OptionalDiffTest {
  @Test("String Conversion")
  func stringConversion() {
    let diffStr = "\(Diff.getDiff(1, nil as Int?))"
    let expected = "different(OptionalDiff(partial(left: \"1\", right: nil)))"
    #expect(diffStr == expected)

    let diffStr2 = "\(Diff.getDiff(nil as Int?, 2))"
    let expected2 = "different(OptionalDiff(partial(left: nil, right: \"2\")))"
    #expect(diffStr2 == expected2)
  }

  @Test("Pretty String Conversion")
  func prettyStringConversion() {
    let diffStr = Diff.getDiff(1, nil as Int?).prettyDescription
    let expected = """
    OptionalDiff:
      Partial:
        Left: "1"
        Right: nil
    """
    #expect(diffStr == expected)

    let diffStr2 = Diff.getDiff(nil as Int?, 2).prettyDescription
    let expected2 = """
    OptionalDiff:
      Partial:
        Left: nil
        Right: "2"
    """
    #expect(diffStr2 == expected2)
  }
}
