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
  let testDir: URL
  let timeProvider: TestTimeProvider

  init() async throws {
    var logger = Logger(label: "io.motns.testing")
    logger.logLevel = .critical
    self.testDir = try TestHelpers.createTestDir()
    self.timeProvider = TestTimeProvider()

    self.exporterDB = try ExporterDB(
      exportDBPath: testDir.appending(path: "export.sqlite"),
      logger: logger,
    )

    self.photosExporterLib = try await PhotosExporterLib.create(
      exportBaseDir: testDir,
      logger: logger,
    )
  }

  deinit {
    if FileManager.default.fileExists(atPath: testDir.path(percentEncoded: false)) {
      try? FileManager.default.removeItem(atPath: testDir.path(percentEncoded: false))
    }
  }

  @Test("Export")
  func export() async throws {
    let expectedInitialRes = PhotosExporterLib.Result(
      assetExport: AssetExporter.Result(
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
      collectionExport: CollectionExporter.Result(
        folderInserted: 1,
        folderUpdated: 0,
        folderUnchanged: 0,
        albumInserted: 0,
        albumUpdated: 0,
        albumUnchanged: 0
      ),
      fileExport: FileExporter.Result(copied: 8, deleted: 0)
    )

    let initialRes = try await photosExporterLib.export()
    #expect(initialRes == expectedInitialRes)

    // TODO - check actual DB contents here
  }
}
