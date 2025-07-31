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
@testable import PhotosExporterLib

actor TestTimeProvider: TimeProvider {
  private var frozenTimestampOpt: TimeInterval?
  var isTimeFrozen: Bool {
    frozenTimestampOpt != nil
  }

  func getDate() -> Date {
    return Date(timeIntervalSince1970: self.frozenTimestampOpt ?? Date().timeIntervalSince1970)
  }

  func unfreezeTime() -> Self {
    frozenTimestampOpt = nil
    return self
  }

  func freezeTime() -> Self {
    frozenTimestampOpt = Date().timeIntervalSince1970
    return self
  }

  func setTime(timestamp: TimeInterval) -> Self {
    frozenTimestampOpt = timestamp
    return self
  }
  func setTime(date: Date) -> Self {
    frozenTimestampOpt = date.timeIntervalSince1970
    return self
  }
  func setTime(timeStr: String) -> Self {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    frozenTimestampOpt = dateFormatter.date(from: timeStr)!.timeIntervalSince1970
    return self
  }

  func advanceTime(seconds: Int) -> Self {
    if !isTimeFrozen {
      _ = freezeTime()
    }

    frozenTimestampOpt = frozenTimestampOpt! + Double(seconds)
    return self
  }
  func advanceTime(minutes: Int) -> Self {
    return advanceTime(seconds: minutes * 60)
  }
  func advanceTime(hours: Int) -> Self {
    return advanceTime(seconds: hours * 3600)
  }
  func advanceTime(days: Int) -> Self {
    return advanceTime(seconds: days * 3600 * 24)
  }

  func secondsPassedSince(_ start: Date) -> TimeInterval {
    return getDate().timeIntervalSince(start)
  }
}
