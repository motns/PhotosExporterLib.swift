import Foundation

public protocol TimeProvider: Actor {
  func getDate() -> Date
}

extension TimeProvider {
  func secondsPassedSince(_ d: Date) -> TimeInterval {
    return getDate().timeIntervalSince(d)
  }
}

actor DefaultTimeProvider: TimeProvider {
  static let shared = DefaultTimeProvider()

  private init() {}

  func getDate() -> Date {
    /*
    There's a known issue with Date serialisation, whereby microseconds are truncated:
    https://github.com/swiftlang/swift-foundation/issues/963
    So the safe option is to use millisecond-precision Dates for now.
    */
    let timestamp = (Date().timeIntervalSince1970 * 1000).rounded() / 1000
    return Date(timeIntervalSince1970: timestamp)
  }

  func secondsPassedSince(_ d: Date) -> TimeInterval {
    return getDate().timeIntervalSince(d)
  }
}

enum TimeProviderError: Error {
  case invalidTimeString(String)
}