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
  let photosExporterLib: PhotosExporterLib
  let exporterDB: ExporterDB
  let testDir: String
  let timeProvider: TestTimeProvider

  init() async throws {
    var logger = Logger(label: "io.motns.testing")
    logger.logLevel = .critical
    self.testDir = try TestHelpers.createTestDir()
    self.timeProvider = TestTimeProvider()

    self.exporterDB = try ExporterDB(
      exportDBPath: testDir + "/export.sqlite",
      logger: logger,
    )

    self.photosExporterLib = try await PhotosExporterLib(
      exportBaseDir: testDir,
      logger: logger,
    )
  }

  deinit {
    if FileManager.default.fileExists(atPath: testDir) {
      try? FileManager.default.removeItem(atPath: testDir)
    }
  }

  @Test("Export")
  func export() async throws {
    let expectedInitialRes = ExportResult(
      assetExport: AssetExportResult(
        assetInserted: 8,
        assetUpdated: 0,
        assetUnchanged: 0,
        assetSkipped: 0,
        assetMarkedForDeletion: 0,
        assetDeleted: 0,
        fileInserted: 8,
        fileUpdated: 0,
        fileUnchanged: 0,
        fileSkipped: 0,
        fileMarkedForDeletion: 0,
        fileDeleted: 0,
      ),
      collectionExport: CollectionExportResult(
        folderInserted: 1,
        folderUpdated: 0,
        folderUnchanged: 0,
        albumInserted: 0,
        albumUpdated: 0,
        albumUnchanged: 0
      ),
      fileExport: FileExportResult(copied: 8, deleted: 0)
    )

    let initialRes = try await photosExporterLib.export()
    #expect(initialRes == expectedInitialRes)
  }
}
