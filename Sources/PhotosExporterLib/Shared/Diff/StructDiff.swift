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
struct StructDiff: Equatable, CustomStringConvertible, PrettyStringConvertible {
  let changes: [String: DiffType]

  var description: String {
    if changes.isEmpty {
      return "StructDiff(same)"
    } else {
      var out = "StructDiff("
      let sortedChanges = changes.toTupleList()
        .sorted { $0.0 < $1.0 }
      out += sortedChanges.map { key, diff in
        "\(key): \(diff)"
      }.joined(separator: ", ")
      out += ")"
      return out
    }
  }

  var prettyDescription: String {
    if changes.isEmpty {
      return ""
    } else {
      let sortedChanges = changes.toTupleList()
        .sorted { $0.0 < $1.0 }
      let changeStr = sortedChanges.map { key, diff in
        """
        \(key):
          \(StringHelper.indent(diff.prettyDescription))
        """
      }.joined(separator: "\n")
      return """
      StructDiff:
        \(StringHelper.indent(changeStr))
      """
    }
  }

  init(changes: [String: DiffType]) {
    self.changes = changes
  }

  init() {
    self.init(changes: [:])
  }

  func add(_ keyResult: (String, DiffResult)) -> StructDiff {
    let (key, diffResult) = keyResult
    switch diffResult {
    case .same: return self
    case .different(let diff):
      var newChanges = self.changes
      newChanges[key] = diff
      return StructDiff(
        changes: newChanges
      )
    }
  }
}
