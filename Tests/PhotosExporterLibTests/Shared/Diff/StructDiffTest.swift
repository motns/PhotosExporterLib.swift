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

@Suite("Struct Diff Test")
struct StructDiffTest {
  @Test("String Conversion")
  func stringConversion() {
    let person1 = Person.create()
    let person2 = person1.copy(
      name: "Peter",
      address: person1.address.copy(
        city: "New York",
      )
    )

    let diffStr = "\(Diff.getDiff(person1, person2))"
    let expected =
      "different(StructDiff(" +
      "\\Person.address: StructDiff(" +
        "\\Address.city: SingleValueDiff(left: \(person1.address.city), right: New York)), " +
      "\\Person.name: SingleValueDiff(left: \(person1.name), right: Peter)" +
      "))"
    #expect(diffStr == expected)
  }

  @Test("Pretty String Conversion")
  func prettyStringConversion() {
    let person1 = Person.create()
    let person2 = person1.copy(
      name: "Peter",
      address: person1.address.copy(
        city: "New York",
      )
    )

    let diffStr = Diff.getDiff(person1, person2).prettyDescription
    let expected = """
    StructDiff:
      \\Person.address:
        StructDiff:
          \\Address.city:
            Left: \(person1.address.city)
            Right: New York
      \\Person.name:
        Left: \(person1.name)
        Right: Peter
    """
    #expect(diffStr == expected)
  }
}
