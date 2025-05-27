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
