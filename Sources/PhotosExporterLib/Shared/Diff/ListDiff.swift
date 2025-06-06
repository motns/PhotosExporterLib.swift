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
struct ListDiff: Equatable, CustomStringConvertible, PrettyStringConvertible {
  let changes: [ListDiffType]

  var description: String {
    var out = "ListDiff("
    out += changes.map { diff in
      "\(diff)"
    }.joined(separator: ", ")
    out += ")"
    return out
  }

  var prettyDescription: String {
    let changeStr = changes.map { diff in
      diff.prettyDescription
    }.joined(separator: "\n")
    return """
    ListDiff:
      \(StringHelper.indent(changeStr))
    """
  }
}

enum ListDiffType: Equatable, CustomStringConvertible, PrettyStringConvertible {
  case added(ListDiffAdded)
  case removed(ListDiffRemoved)
  case changed(ListDiffChanged)

  var description: String {
    switch self {
    case .added(let diff): "\(diff)"
    case .removed(let diff): "\(diff)"
    case .changed(let diff): "\(diff)"
    }
  }

  var prettyDescription: String {
    switch self {
    case .added(let diff): diff.prettyDescription
    case .removed(let diff): diff.prettyDescription
    case .changed(let diff): diff.prettyDescription
    }
  }
}

struct ListDiffAdded: Equatable, CustomStringConvertible, PrettyStringConvertible {
  let index: Int
  let element: String

  var description: String {
    "[\(index)]added: \(element)"
  }

  var prettyDescription: String {
    return """
    Added at \(index):
      \(StringHelper.indent(String(describing: element)))
    """
  }
}

struct ListDiffRemoved: Equatable, CustomStringConvertible, PrettyStringConvertible {
  let index: Int
  let element: String

  var description: String {
    "[\(index)]removed: \(element)"
  }

  var prettyDescription: String {
    return """
    Removed at \(index):
      \(StringHelper.indent(String(describing: element)))
    """
  }
}

struct ListDiffChanged: Equatable, CustomStringConvertible, PrettyStringConvertible {
  let index: Int
  let diff: DiffType

  var description: String {
    "[\(index)]changed: \(diff)"
  }

  var prettyDescription: String {
    return """
    Changed at \(index):
      \(StringHelper.indent(diff.prettyDescription))
    """
  }
}
