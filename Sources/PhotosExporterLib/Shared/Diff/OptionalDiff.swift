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
enum OptionalDiff: Equatable, CustomStringConvertible, PrettyStringConvertible {
  case partial(OptionalDiffPartial)
  case diff(DiffType)

  var description: String {
    let diffStr = switch self {
    case .partial(let diffPartial): "\(diffPartial)"
    case .diff(let diff): "\(diff)"
    }
    return "OptionalDiff(\(diffStr))"
  }

  var prettyDescription: String {
    let diffStr = switch self {
    case .partial(let diffPartial): diffPartial.prettyDescription
    case .diff(let diff): diff.prettyDescription
    }
    return """
    OptionalDiff:
      \(StringHelper.indent(diffStr))
    """
  }
}

struct OptionalDiffPartial: Equatable, CustomStringConvertible, PrettyStringConvertible {
  let left: String?
  let right: String?

  var description: String {
    let leftStr = if let left {
      "\"\(left)\""
    } else {
      "nil"
    }
    let rightStr = if let right {
      "\"\(right)\""
    } else {
      "nil"
    }
    var out = "partial("
    out += "left: \(leftStr)"
    out += ", right: \(rightStr)"
    out += ")"
    return out
  }

  var prettyDescription: String {
    let leftStr = if let left {
      "\"\(left)\""
    } else {
      "nil"
    }
    let rightStr = if let right {
      "\"\(right)\""
    } else {
      "nil"
    }
    return """
    Partial:
      Left: \(leftStr)
      Right: \(rightStr)
    """
  }
}
