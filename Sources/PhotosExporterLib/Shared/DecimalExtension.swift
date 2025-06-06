import Foundation

extension Decimal {
  func rounded(scale: Int) -> Decimal {
    var result = Decimal()
    var input = self
    NSDecimalRound(&result, &input, scale, .plain)
    return result
  }
}
