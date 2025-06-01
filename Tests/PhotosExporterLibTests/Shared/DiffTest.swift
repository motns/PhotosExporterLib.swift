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

@Suite("Diff Test")
final class DiffTest {
  @Test("Get Diff - Matching")
  func getDiffAsStringMatching() {
    let person1 = Person(name: "Peter", age: 21)
    let person2 = Person(name: "Bruce", age: 35)
    let person3 = Person(name: "Tony", age: 40)
    let list1 = [person1, person2, person3]
    let list2 = [person1, person2, person3]
    #expect(Diff.getDiffAsString(list1, list2) == nil)
  }

  @Test("Get Diff - Added")
  func getDiffAsStringAdded() {
    let person1 = Person(name: "Peter", age: 21)
    let person2 = Person(name: "Bruce", age: 35)
    let person3 = Person(name: "Tony", age: 40)
    let list1 = [person1, person2]
    let list2 = [person1, person2, person3]
    let diffStr = """
    Lists did not match:
      Added in Right at 2:
        Person(name: "Tony", age: 40)
    """
    #expect(Diff.getDiffAsString(list1, list2) == diffStr)
  }

  @Test("Get Diff - Removed")
  func getDiffAsStringRemoved() {
    let person1 = Person(name: "Peter", age: 21)
    let person2 = Person(name: "Bruce", age: 35)
    let person3 = Person(name: "Tony", age: 40)
    let list1 = [person1, person2, person3]
    let list2 = [person1, person2]
    let diffStr = """
    Lists did not match:
      Missing from Right at 2:
        Person(name: "Tony", age: 40)
    """
    #expect(Diff.getDiffAsString(list1, list2) == diffStr)
  }

  @Test("Get Diff - Changed")
  func getDiffAsStringChanged() {
    let person1 = Person(name: "Peter", age: 21)
    let person2 = Person(name: "Bruce", age: 35)
    let person2Updated = Person(name: "Banner", age: 36)
    let person3 = Person(name: "Tony", age: 40)
    let person3Updated = Person(name: "Stark", age: 41)
    let list1 = [person1, person2, person3]
    let list2 = [person1, person2Updated, person3Updated]
    let diffStr = """
    Lists did not match:
      Changed at 1:
        name:
          Left: Bruce
          Right: Banner
        age:
          Left: 35
          Right: 36
      Changed at 2:
        name:
          Left: Tony
          Right: Stark
        age:
          Left: 40
          Right: 41
    """
    #expect(Diff.getDiffAsString(list1, list2) == diffStr)
  }
}

private struct Person: Diffable, DiffableStruct {
  let name: String
  let age: Int

  func getDiffAsString(_ other: Person) -> String? {
    var out = ""
    out += propertyDiff("name", self.name, other.name) ?? ""
    out += propertyDiff("age", self.age, other.age) ?? ""
    return out != "" ? out : nil
  }
}
