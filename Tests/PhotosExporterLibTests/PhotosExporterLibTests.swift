import Foundation
import Logging
import Testing

@testable import PhotosExporterLib

@Suite("Photos Exporter Lib Tests")
final class PhotosExporterLibTests {
  let photosExporterLib: PhotosExporterLib
  let exporterDB: ExporterDB
  var photokitMock: PhotokitMock
  var photosDBMock: PhotosDBMock
  let testDir: String
  let timeProvider: TestTimeProvider
  let countryLookup: CachedLookupTable
  let cityLookup: CachedLookupTable
  let dataGen: TestDataGenerator

  init() async throws {
    var logger = Logger(label: "io.motns.testing")
    logger.logLevel = .critical
    self.testDir = try TestHelpers.createTestDir()

    self.photokitMock = PhotokitMock()
    self.photosDBMock = PhotosDBMock()
    self.timeProvider = TestTimeProvider()

    self.exporterDB = try ExporterDB(
      exportDBPath: testDir + "/testdb.sqlite",
      logger: logger,
    )
    self.dataGen = TestDataGenerator(exporterDB: exporterDB)
    self.countryLookup = CachedLookupTable(table: .country, exporterDB: exporterDB, logger: logger)
    self.cityLookup = CachedLookupTable(table: .city, exporterDB: exporterDB, logger: logger)

    self.photosExporterLib = PhotosExporterLib(
      exportBaseDir: testDir,
      photokit: self.photokitMock,
      exporterDB: exporterDB,
      photosDB: self.photosDBMock,
      logger: logger,
      timeProvider: self.timeProvider,
    )
  }

  deinit {
    if FileManager.default.fileExists(atPath: testDir) {
      try? FileManager.default.removeItem(atPath: testDir)
    }
  }

  @Test("Export - Empty DB")
  // swiftlint:disable:next function_body_length
  func exportIntoEmptyDB() async throws {
    let now = timeProvider.getDate()
    let exportBaseDirURL = URL(filePath: testDir)
    let fileDirURL = exportBaseDirURL.appending(path: "files")

    let resource1 = dataGen.createPhotokitAssertResource()
    let resource2 = dataGen.createPhotokitAssertResource()
    let resource3 = dataGen.createPhotokitAssertResource()

    let asset1 = try dataGen.createPhotokitAsset(
      assetId: "E5481A99-EF62-41D4-B438-F878186E5903",
      resources: [resource1],
    )
    let asset2 = try dataGen.createPhotokitAsset(
      assetId: "E94FE51B-4567-4E30-ADE7-77BFDFE6174E",
      resources: [resource2],
    )
    let asset3 = try dataGen.createPhotokitAsset(
      assetId: "F2B766A4-D8C2-4BA9-836B-3055445525F0",
      assetLibrary: .sharedAlbum,
      resources: [resource3],
    )

    self.photokitMock.assets = [asset1, asset2, asset3]

    self.photosDBMock.assetLocations = [
      asset1.id: dataGen.createPostalAddress(country: "United Kingdom", city: "London"),
      asset2.id: dataGen.createPostalAddress(country: "Spain", city: "Madrid"),
      // asset3 won't have location data
    ]

    let exportedAsset1 = ExportedAsset.fromPhotokitAsset(
      asset: asset1,
      cityId: try cityLookup.getIdByName(name: "London"),
      countryId: try countryLookup.getIdByName(name: "United Kingdom"),
      now: now,
    )!
    let exportedFile1 = ExportedFile.fromPhotokitAssetResource(
      asset: asset1,
      resource: asset1.resources[0],
      countryOpt: "United Kingdom",
      cityOpt: "London",
      now: now,
    )!.copy(wasCopied: true)

    let exportedAsset2 = ExportedAsset.fromPhotokitAsset(
      asset: asset2,
      cityId: try cityLookup.getIdByName(name: "Madrid"),
      countryId: try countryLookup.getIdByName(name: "Spain"),
      now: now,
    )!
    let exportedFile2 = ExportedFile.fromPhotokitAssetResource(
      asset: asset2,
      resource: asset2.resources[0],
      countryOpt: "Spain",
      cityOpt: "Madrid",
      now: now,
    )!.copy(wasCopied: true)

    let exportedAsset3 = ExportedAsset.fromPhotokitAsset(
      asset: asset3,
      cityId: nil,
      countryId: nil,
      now: now,
    )!
    let exportedFile3 = ExportedFile.fromPhotokitAssetResource(
      asset: asset3,
      resource: asset3.resources[0],
      countryOpt: nil,
      cityOpt: nil,
      now: now,
    )!.copy(wasCopied: true)

    let exportedAssets = [
      exportedAsset1,
      exportedAsset2,
      exportedAsset3,
    ].sorted(by: { $0.id < $1.id })
    let exportedFiles = [
      exportedFile1,
      exportedFile2,
      exportedFile3,
    ].sorted(by: { $0.id < $1.id })

    let expectedRes = ExportResult(
      assetExport: AssetExportResult(
        assetInserted: 3,
        assetUpdated: 0,
        assetUnchanged: 0,
        assetSkipped: 0,
        fileInserted: 3,
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
      fileCopy: FileCopyResult(copied: 3, removed: 0)
    )

    let res = try await self.photosExporterLib.export()
    #expect(res == expectedRes)

    let expectedCopyCalls = [
      CopyResourceCall(
        assetId: asset1.id,
        resourceType: asset1.resources[0].assetResourceType,
        originalFileName: asset1.resources[0].originalFileName,
        destination:
          fileDirURL
            .appending(path: exportedFile1.importedFileDir)
            .appending(path: exportedFile1.importedFileName),
      ),
      CopyResourceCall(
        assetId: asset2.id,
        resourceType: asset2.resources[0].assetResourceType,
        originalFileName: asset2.resources[0].originalFileName,
        destination:
          fileDirURL
            .appending(path: exportedFile2.importedFileDir)
            .appending(path: exportedFile2.importedFileName),
      ),
      CopyResourceCall(
        assetId: asset3.id,
        resourceType: asset3.resources[0].assetResourceType,
        originalFileName: asset3.resources[0].originalFileName,
        destination:
          fileDirURL
            .appending(path: exportedFile3.importedFileDir)
            .appending(path: exportedFile3.importedFileName),
      ),
    ]

    #expect(Set(self.photokitMock.copyResourceCalls) == Set(expectedCopyCalls))

    let assetsInDB = try exporterDB.getAllAssets().sorted(by: { $0.id < $1.id })
    // Avoid using Sets, because they use Hashable instead of Comparable
    #expect(assetsInDB == exportedAssets)

    let filesInDB = try exporterDB.getAllFiles().sorted(by: { $0.id < $1.id })
    #expect(filesInDB == exportedFiles)
  }
}
