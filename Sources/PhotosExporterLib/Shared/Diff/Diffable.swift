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

protocol Diffable: Equatable {
  func diff(_ other: Self) -> DiffResult
}

protocol SingleValueDiffable: Diffable {}

extension SingleValueDiffable {
  func diff(_ other: Self) -> DiffResult {
    if self == other {
      return .same
    } else {
      return .different(
        .singleValue(
          SingleValueDiff(left: "\(self)", right: "\(other)")
        )
      )
    }
  }
}

protocol DiffableStruct: Diffable, Equatable {
  func getStructDiff(_ other: Self) -> StructDiff
}

extension DiffableStruct {
  func diff(_ other: Self) -> DiffResult {
    let structDiff = getStructDiff(other)

    if structDiff.changes.isEmpty {
      return .same
    } else {
      return .different(
        .structDiff(structDiff)
      )
    }
  }

  func diffProperty<T: Diffable>(_ other: Self, _ keyPath: KeyPath<Self, T>) -> (String, DiffResult) {
    let lhs = self[keyPath: keyPath]
    let rhs = other[keyPath: keyPath]
    return (String(describing: keyPath), Diff.getDiff(lhs, rhs))
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    return switch lhs.diff(rhs) {
    case .same: true
    case .different: false
    }
  }
}
