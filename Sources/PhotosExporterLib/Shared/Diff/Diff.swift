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

struct Diff {
  // Single Value types
  static func getDiff<T: Diffable>(_ lhs: T, _ rhs: T) -> DiffResult {
    return lhs.diff(rhs)
  }

  // Optional
  static func getDiff<T: Diffable>(_ lhsOpt: T?, _ rhsOpt: T?) -> DiffResult {
    return switch (lhsOpt, rhsOpt) {
    case (nil, nil): .same
    case (nil, .some(let rhs)):
      .different(.optional(.partial(
        OptionalDiffPartial(left: nil, right: String(describing: rhs))
      )))
    case (.some(let lhs), nil):
      .different(.optional(.partial(
        OptionalDiffPartial(left: String(describing: lhs), right: nil)
      )))
    case (.some(let lhs), .some(let rhs)):
      // Technically we'll never make it here, because non-optional values
      // will be matched to one of the other `getDiff` methods
      switch lhs.diff(rhs) {
      case .same: .same
      case .different(let diff):
        .different(
          .optional(.diff(diff))
        )
      }
    }
  }

  // Set
  static func getDiff<Element: Diffable>(_ lhs: Set<Element>, _ rhs: Set<Element>) -> DiffResult {
    let onlyInLeft = lhs.subtracting(rhs).map { el in
      String(describing: el)
    }
    let onlyInRight = rhs.subtracting(lhs).map { el in
      String(describing: el)
    }

    if onlyInLeft.isEmpty && onlyInRight.isEmpty {
      return .same
    } else {
      return .different(
        .set(
          SetDiff(onlyInLeft: onlyInLeft, onlyInRight: onlyInRight)
        )
      )
    }
  }

  // List
  static func getDiff<Element: Diffable>(_ lhs: [Element], _ rhs: [Element]) -> DiffResult {
    var leftIterator = lhs.enumerated().makeIterator()
    var rightIterator = rhs.enumerated().makeIterator()

    return getDiff(
      &leftIterator,
      &rightIterator,
    )
  }

  // Iterator
  // swiftlint:disable:next function_body_length
  static func getDiff<Element: Diffable>(
    _ leftIterator: inout EnumeratedSequence<[Element]>.Iterator,
    _ rightIterator: inout EnumeratedSequence<[Element]>.Iterator,
    changes: [ListDiffType] = [],
  ) -> DiffResult {
    let leftOpt = leftIterator.next()
    let rightOpt = rightIterator.next()

    switch (leftOpt, rightOpt) {
    case (nil, nil): // We're finished
      if changes.isEmpty {
        return .same
      } else {
        return .different(
          .list(ListDiff(changes: changes))
        )
      }
    case (let .some((idx, lhs)), nil):
      return getDiff(
        &leftIterator,
        &rightIterator,
        changes: changes + [
          .removed(
            ListDiffRemoved(index: idx, element: "\(lhs)")
          ),
        ]
      )

    case (nil, let .some((idx, rhs))):
      return getDiff(
        &leftIterator,
        &rightIterator,
        changes: changes + [
          .added(
            ListDiffAdded(index: idx, element: "\(rhs)")
          ),
        ]
      )

    case (let .some((idx, lhs)), let .some((_, rhs))):
      switch lhs.diff(rhs) {
      case .same:
        return getDiff(
          &leftIterator,
          &rightIterator,
          changes: changes
        )
      case .different(let elDiff):
        return getDiff(
          &leftIterator,
          &rightIterator,
          changes: changes + [
            .changed(
              ListDiffChanged(index: idx, diff: elDiff)
            ),
          ]
        )
      }
    }
  }

  // Struct
  static func getDiff<T: DiffableStruct>(_ lhs: T, _ rhs: T) -> DiffResult {
    return lhs.diff(rhs)
  }
}

enum DiffResult: Equatable, CustomStringConvertible, PrettyStringConvertible {
  case same
  case different(DiffType)

  var description: String {
    switch self {
    case .same: "same"
    case .different(let diff): "different(\(diff))"
    }
  }

  var prettyDescription: String {
    switch self {
    case .same: "Same"
    case .different(let diff): diff.prettyDescription
    }
  }
}

indirect enum DiffType: Equatable, CustomStringConvertible, PrettyStringConvertible {
  case singleValue(SingleValueDiff)
  case optional(OptionalDiff)
  case set(SetDiff)
  case list(ListDiff)
  case structDiff(StructDiff)

  var description: String {
    return switch self {
    case .singleValue(let diff): "\(diff)"
    case .optional(let diff): "\(diff)"
    case .set(let diff): "\(diff)"
    case .list(let diff): "\(diff)"
    case .structDiff(let diff): "\(diff)"
    }
  }

  var prettyDescription: String {
    return switch self {
    case .singleValue(let diff): diff.prettyDescription
    case .optional(let diff): diff.prettyDescription
    case .set(let diff): diff.prettyDescription
    case .list(let diff): diff.prettyDescription
    case .structDiff(let diff): diff.prettyDescription
    }
  }
}
