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

struct Person: DiffableStruct {
  let id: Int
  let name: String
  let isEmployee: Bool
  let address: Address

  func getStructDiff(_ other: Person) -> StructDiff {
    return StructDiff()
      .add(diffProperty(other, \.id))
      .add(diffProperty(other, \.name))
      .add(diffProperty(other, \.isEmployee))
      .add(diffProperty(other, \.address))
  }

  func copy(
    id: Int? = nil,
    name: String? = nil,
    isEmployee: Bool? = nil,
    address: Address? = nil,
  ) -> Person {
    return Person(
      id: id ?? self.id,
      name: name ?? self.name,
      isEmployee: isEmployee ?? self.isEmployee,
      address: address ?? self.address,
    )
  }

  static func create() -> Person {
    return Person(
      id: Int.random(in: 1...99999),
      name: "Peter \(Int.random(in: 1...9999))",
      isEmployee: Bool.random(),
      address: Address.create(),
    )
  }
}

struct Address: DiffableStruct {
  let street: String
  let city: String
  let postcode: String

  func getStructDiff(_ other: Address) -> StructDiff {
    return StructDiff()
      .add(diffProperty(other, \.street))
      .add(diffProperty(other, \.city))
      .add(diffProperty(other, \.postcode))
  }

  func copy(
    street: String? = nil,
    city: String? = nil,
    postcode: String? = nil,
  ) -> Address {
    return Address(
      street: street ?? self.street,
      city: city ?? self.city,
      postcode: postcode ?? self.postcode,
    )
  }

  static func create() -> Address {
    return Address(
      street: "Some street \(Int.random(in: 1...9999))",
      city: "City \(Int.random(in: 1...9999))",
      postcode: "\(Int.random(in: 11111...99999))",
    )
  }
}

@Suite("Diff Test")
struct DiffTest {
  @Test("Diff Single Value - Same")
  func getDiffSingleValueSame() {
    #expect(Diff.getDiff("hello", "hello") == .same)
    #expect(Diff.getDiff(1, 1) == .same)
    #expect(Diff.getDiff(Int64(2), Int64(2)) == .same)
    #expect(Diff.getDiff(Decimal(3), Decimal(3)) == .same)
    #expect(Diff.getDiff(false, false) == .same)
    #expect(Diff.getDiff(URL(filePath: "/tmp"), URL(filePath: "/tmp")) == .same)
  }

  @Test("Diff Single Value - Different")
  func getDiffSingleValueDifferent() {
    #expect(
      Diff.getDiff("hello", "bye") == .different(.singleValue(
        SingleValueDiff(left: "hello", right: "bye")
      ))
    )

    #expect(
      Diff.getDiff(1, 2) == .different(.singleValue(
        SingleValueDiff(left: "1", right: "2")
      ))
    )

    #expect(
      Diff.getDiff(Int64(3), Int64(4)) == .different(.singleValue(
        SingleValueDiff(left: "3", right: "4")
      ))
    )

    #expect(
      Diff.getDiff(Decimal(5), Decimal(6)) == .different(.singleValue(
        SingleValueDiff(left: "5", right: "6")
      ))
    )

    #expect(
      Diff.getDiff(true, false) == .different(.singleValue(
        SingleValueDiff(left: "true", right: "false")
      ))
    )

    #expect(
      Diff.getDiff(URL(filePath: "/tmp"), URL(filePath: "/home")) == .different(.singleValue(
        SingleValueDiff(left: "file:///tmp", right: "file:///home")
      ))
    )
  }

  @Test("Diff Optional - Same")
  func getDiffOptionalSame() {
    #expect(Diff.getDiff(nil as Int?, nil as Int?) == .same)
  }

  @Test("Diff Optional - Different")
  func getDiffOptionalDifferent() {
    #expect(
      Diff.getDiff(nil as Int?, 1) == .different(.optional(.partial(
        OptionalDiffPartial(left: nil, right: "1")
      )))
    )
  }

  @Test("Diff Set - Same")
  func getDiffSetSame() {
    #expect(Diff.getDiff(Set([1, 2, 3]), Set([3, 2, 1])) == .same)
  }

  @Test("Diff Set - Different")
  func getDiffSetDifferent() {
    #expect(
      Diff.getDiff(Set([2, 3, 4]), Set([3, 2, 1])) == .different(.set(
        SetDiff(onlyInLeft: ["4"], onlyInRight: ["1"])
      ))
    )
  }

  @Test("Diff List - Same")
  func getDiffListSame() {
    #expect(Diff.getDiff([Person](), [Person]()) == .same)
    #expect(Diff.getDiff([1, 2], [1, 2]) == .same)
    #expect(Diff.getDiff(["hello"], ["hello"]) == .same)

    let person = Person.create()
    #expect(Diff.getDiff([person], [person]) == .same)
  }

  @Test("Diff List - Different")
  // swiftlint:disable:next function_body_length
  func getDiffListDifferent() {
    #expect(
      Diff.getDiff([1, 2], [1, 3]) == .different(
        .list(ListDiff(changes: [
          .changed(ListDiffChanged(
            index: 1,
            diff: .singleValue(SingleValueDiff(left: "2", right: "3"))
          )),
        ]))
      )
    )

    #expect(
      Diff.getDiff([1, 2, 3], [1, 2]) == .different(
        .list(ListDiff(changes: [
          .removed(ListDiffRemoved(
            index: 2,
            element: "3"
          )),
        ]))
      )
    )

    #expect(
      Diff.getDiff([1, 2], [1, 2, 3]) == .different(
        .list(ListDiff(changes: [
          .added(ListDiffAdded(
            index: 2,
            element: "3"
          )),
        ]))
      )
    )

    let person1 = Person.create()
    let person2 = person1.copy(
      name: "Kevin",
      address: person1.address.copy(
        city: "Gotham",
      )
    )
    #expect(
      Diff.getDiff([person1], [person2]) == .different(
        .list(ListDiff(changes: [
          .changed(ListDiffChanged(
            index: 0,
            diff: .structDiff(StructDiff(
              changes: [
                "\\Person.name": .singleValue(
                  SingleValueDiff(left: person1.name, right: "Kevin")
                ),
                "\\Person.address": .structDiff(
                  StructDiff(changes: [
                    "\\Address.city": .singleValue(
                      SingleValueDiff(left: person1.address.city, right: "Gotham")
                    ),
                  ]),
                ),
              ]
            ))
          )),
        ]))
      )
    )
  }

  @Test("Diff Struct - Same")
  func getDiffStructSame() {
    let person1 = Person.create()
    let person2 = person1.copy()
    #expect(Diff.getDiff(person1, person2) == .same)
  }

  @Test("Diff Struct - Different")
  func getDiffStructDifferent() {
    let person1 = Person.create()
    let person2 = person1.copy(
      name: "Peter",
      address: person1.address.copy(
        city: "New York",
      )
    )
    #expect(
      Diff.getDiff(person1, person2) == .different(.structDiff(
        StructDiff(changes: [
          "\\Person.name": .singleValue(
            SingleValueDiff(left: person1.name, right: "Peter"),
          ),
          "\\Person.address": .structDiff(
            StructDiff(changes: [
              "\\Address.city": .singleValue(
                SingleValueDiff(left: person1.address.city, right: "New York")
              ),
            ])
          ),
        ])
      ))
    )
  }
}

@Suite("DiffResult Test")
struct DiffResultTest {
  @Test("String Conversion")
  func stringConversion() {
    #expect("\(DiffResult.same)" == "same")

    let diff = DiffResult.different(.singleValue(
      SingleValueDiff(left: "a", right: "b")
    ))
    let expected = "different(SingleValueDiff(left: a, right: b))"
    #expect("\(diff)" == expected)
  }

  @Test("Pretty String Conversion")
  func prettyString() {
    #expect(DiffResult.same.prettyDescription == "Same")

    let diff = DiffResult.different(.singleValue(
      SingleValueDiff(left: "a", right: "b")
    ))
    let expected = """
    Left: a
    Right: b
    """
    #expect(diff.prettyDescription == expected)
  }
}
