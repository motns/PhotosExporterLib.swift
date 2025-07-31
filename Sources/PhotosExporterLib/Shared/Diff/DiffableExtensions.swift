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

extension String: SingleValueDiffable {}

extension Int: SingleValueDiffable {}

extension Int64: SingleValueDiffable {}

extension Decimal: SingleValueDiffable {}

extension Bool: SingleValueDiffable {}

extension URL: SingleValueDiffable {}

extension Double: Diffable {
  func diff(_ other: Double) -> DiffResult {
    if Int(self * 1_000_000) == Int(other * 1_000_000) {
      return .same
    } else {
      return .different(
        .singleValue(
          SingleValueDiff(
            left: "\(self)",
            right: "\(other)",
          )
        )
      )
    }
  }
}

extension Date: Diffable {
  func diff(_ other: Self) -> DiffResult {
    if DateHelper.secondsEquals(self, other) {
      return .same
    } else {
      return .different(
        .singleValue(
          SingleValueDiff(
            left: self.toDebugString(),
            right: other.toDebugString(),
          )
        )
      )
    }
  }

  // We introduce this extra format because the regular
  // datetime string hides fractional second differences
  func toDebugString() -> String {
    let dateTime = ISO8601DateFormatter().string(from: self)
    return "Date(\(dateTime), \(self.timeIntervalSince1970))"
  }
}

extension Optional: Diffable where Wrapped: Diffable {
  func diff(_ other: Self) -> DiffResult {
    Diff.getDiff(self, other)
  }
}

extension Array: Diffable where Element: Diffable {
  func diff(_ other: Self) -> DiffResult {
    Diff.getDiff(self, other)
  }
}

extension Set: Diffable where Element: Diffable {
  func diff(_ other: Self) -> DiffResult {
    Diff.getDiff(self, other)
  }
}
