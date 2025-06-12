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

public protocol TimeProvider {
  func getDate() -> Date
  func secondsPassedSince(_ start: Date) -> TimeInterval
}

struct DefaultTimeProvider: TimeProvider {
  static let shared = DefaultTimeProvider()

  private init() {}

  func getDate() -> Date {
    /*
    There's a known issue with Date serialisation, whereby microseconds are truncated:
    https://github.com/swiftlang/swift-foundation/issues/963
    Also, we don't really need timestamps with sub-second precision, so we'll try to avoid
    having to deal with Doubles as much as we can.
    */
    return Date(
      timeIntervalSince1970: Double(Int(Date().timeIntervalSince1970))
    )
  }

  func secondsPassedSince(_ start: Date) -> TimeInterval {
    return getDate().timeIntervalSince(start)
  }
}
