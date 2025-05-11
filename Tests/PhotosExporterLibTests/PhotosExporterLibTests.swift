import Foundation
import Logging
import Testing
@testable import PhotosExporterLib

@Suite("Photos Exporter Lib Tests")
final class PhotosExporterLibTests {
  let photosExporterLib: PhotosExporterLib
  let photokitMock: PhotokitMock
  let testDir: String
  let timeProvider: TimeProvider

  init() async throws {
    var logger = Logger(label: "io.motns.testing")
    logger.logLevel = .critical
    self.testDir = try TestHelpers.createTestDir()

    self.photokitMock = PhotokitMock()
    self.timeProvider = TestTimeProvider()
    let exporterDB = try await ExporterDB(
      exportDBPath: testDir + "/testdb.sqlite",
      logger: logger,
      timeProvider: self.timeProvider,
    )

    self.photosExporterLib = PhotosExporterLib(
      exportBaseDir: testDir,
      photokit: self.photokitMock,
      exporterDB: exporterDB,
      photosDB: PhotosDBMock(),
      countryLookup: CachedLookupTable(table: .country, exporterDB: exporterDB, logger: logger),
      cityLookup: CachedLookupTable(table: .city, exporterDB: exporterDB, logger: logger),
      classLogger: ClassLogger(logger: logger, className: "PhotosExporterLib"),
      timeProvider: self.timeProvider,
    )
  }

  deinit {
    if FileManager.default.fileExists(atPath: testDir) {
      try? FileManager.default.removeItem(atPath: testDir)
    }
  }

  @Test("Export")
  func export() async throws {
    let expectedRes = ExportResult(
      assetExport: AssetExportResult(
        assetInserted: 0,
        assetUpdated: 0,
        assetUnchanged: 0,
        assetSkipped: 0,
        fileInserted: 0,
        fileUpdated: 0,
        fileUnchanged: 0,
        fileSkipped: 0
      ),
      collectionExport: CollectionExportResult(
        folderInserted: 1,
        folderUpdated: 0,
        folderUnchanged: 0,
        albumInserted: 0,
        albumUpdated: 0,
        albumUnchanged: 0
      ),
      fileCopy: FileCopyResults(copied: 0, removed: 0)
    )

    let res = try await self.photosExporterLib.export()
    #expect(res == expectedRes)
  }
}

actor PhotokitMock: PhotokitProtocol {
  func getAssetIdsForAlbumId(albumId: String) -> [String] {
    return []
  }

  func getRootFolder() throws -> PhotokitFolder {
    return PhotokitFolder(
      id: Photokit.RootFolderId,
      title: "Untitled",
      parentId: nil,
      subfolders: [],
      albums: []
    )
  }

  func getFolder(folderId: String, parentIdOpt: String?) throws -> PhotokitFolder {
    return PhotokitFolder(
      id: folderId,
      title: "TODO",
      parentId: parentIdOpt,
      subfolders: [],
      albums: []
    )
  }

  func getSharedAlbums() -> [PhotokitAlbum] {
    return []
  }

  func getAllAssets() async -> [PhotokitAsset] {
    return []   
  }

  func copyResource(
    assetId: String,
    fileType: FileType,
    originalFileName: String, destination: URL) async throws -> ResourceCopyResult {
    return ResourceCopyResult.copied
  }
}

actor PhotosDBMock: PhotosDBProtocol {
  func getAllAssetLocationsById() async throws -> [String : PostalAddress] {
    return [:]
  }
}