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

struct DateHelper {
  static func secondsEquals(_ date1: Date, _ date2: Date) -> Bool {
    return Int(date1.timeIntervalSince1970) == Int(date2.timeIntervalSince1970)
  }

  static func secondsEquals(_ date1: Date?, _ date2: Date?) -> Bool {
    return switch (date1, date2) {
    case (.none, .none): true
    case (.none, .some(_)): false
    case (.some(_), .none): false
    case (.some(let date1), .some(let date2)):
      secondsEquals(date1, date2)
    }
  }

  static func getYearStr(_ date: Date?) -> String {
    let calendar = Calendar.current
    if let date {
      return String(calendar.component(.year, from: date))
    } else {
      return "0000"
    }
  }

  static func getMonthStr(_ date: Date?) -> String {
    let calendar = Calendar.current
    if let date {
      return String(format: "%02d", calendar.component(.month, from: date))
    } else {
      return "00"
    }
  }

  static func getYearMonthStr(_ date: Date?) -> String {
    if let date {
      let year = getYearStr(date)
      let month = getMonthStr(date)
      return "\(year)-\(month)"
    } else {
      return "0000-00"
    }
  }
}
