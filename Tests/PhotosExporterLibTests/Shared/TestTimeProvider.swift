import Foundation
@testable import PhotosExporterLib

final class TestTimeProvider: TimeProvider {
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
