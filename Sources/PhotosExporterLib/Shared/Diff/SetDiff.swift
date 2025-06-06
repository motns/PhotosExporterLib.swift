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
struct SetDiff: Equatable, CustomStringConvertible, PrettyStringConvertible {
  let onlyInLeft: [String]
  let onlyInRight: [String]

  var description: String {
    var out = "SetDiff("
    if !onlyInLeft.isEmpty {
      out += "onlyInLeft: ["
      out += onlyInLeft.joined(separator: ",")
      out += "]"
    }
    if !onlyInRight.isEmpty {
      if !onlyInLeft.isEmpty {
        out += ", "
      }
      out += "onlyInRight: ["
      out += onlyInRight.joined(separator: ",")
      out += "]"
    }
    out += ")"
    return out
  }

  var prettyDescription: String {
    var out = """
    SetDiff:
    """
    if !onlyInLeft.isEmpty {
      out += """
      \n  Only in Left:
          \(StringHelper.indent(
            onlyInLeft.joined(separator: "\n")
          ))
      """
    }
    if !onlyInRight.isEmpty {
      out += """
      \n  Only in Right:
          \(StringHelper.indent(
            onlyInRight.joined(separator: "\n")
          ))
      """
    }
    return out
  }
}
