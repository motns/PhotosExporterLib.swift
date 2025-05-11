import Foundation
import Logging
import Testing
@testable import PhotosExporterLib

@Suite(
  "Photos Exporter Lib Live Tests",
  .enabled(
    if: ProcessInfo.processInfo.environment["LIVE_TEST"] == "1",
    "Only enable this in a test VM"
  )
)
final class PhotosExporterLibLiveTests {
  @Test("Export")
  func export() async throws {
  }
}