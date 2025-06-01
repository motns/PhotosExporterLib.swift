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
