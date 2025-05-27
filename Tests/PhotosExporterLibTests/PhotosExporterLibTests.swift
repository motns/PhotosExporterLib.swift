import Foundation
import Logging
import Testing

@testable import PhotosExporterLib

@Suite("Photos Exporter Lib Tests")
// swiftlint:disable:next type_body_length
final class PhotosExporterLibTests {
  let photosExporterLib: PhotosExporterLib
  let exporterDB: ExporterDB
  var photokitMock: PhotokitMock
  var photosDBMock: PhotosDBMock
  let fileManagerMock: ExporterFileManagerMock
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
    self.fileManagerMock = ExporterFileManagerMock()
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
      fileManager: self.fileManagerMock,
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
    // - MARK: Set up test data
    let now = timeProvider.getDate()
    let exportBaseDirURL = URL(filePath: testDir)

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

    let album1 = dataGen.createPhotokitAlbum(
      collectionSubtype: .albumCloudShared,
      assetIds: [asset1.id],
    )
    let album2 = dataGen.createPhotokitAlbum(assetIds: [asset2.id])
    let album3 = dataGen.createPhotokitAlbum(assetIds: [asset3.id])

    let folder2 = dataGen.createPhotokitFolder(albums: [album3])
    let folder1 = dataGen.createPhotokitFolder(
      subfolders: [folder2],
      albums: [album2],
    )
    self.photokitMock.rootAlbums = [album1]
    self.photokitMock.rootFolders = [folder1]
    self.photokitMock.albums = [album1, album2, album3]

    // - MARK: Create expected models
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
    let assetFile1 = ExportedAssetFile(
      assetId: exportedAsset1.id,
      fileId: exportedFile1.id,
      isDeleted: false,
      deletedAt: nil
    )

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
    let assetFile2 = ExportedAssetFile(
      assetId: exportedAsset2.id,
      fileId: exportedFile2.id,
      isDeleted: false,
      deletedAt: nil
    )

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
    let assetFile3 = ExportedAssetFile(
      assetId: exportedAsset3.id,
      fileId: exportedFile3.id,
      isDeleted: false,
      deletedAt: nil
    )

    let exportedFolder1 = ExportedFolder.fromPhotokitFolder(
      folder: folder1,
      parentId: Photokit.RootFolderId,
    )
    let exportedFolder2 = ExportedFolder.fromPhotokitFolder(
      folder: folder2,
      parentId: folder1.id,
    )

    let exportedAlbum1 = try ExportedAlbum.fromPhotokitAlbum(
      album: album1,
      folderId: Photokit.RootFolderId,
    )
    let exportedAlbum2 = try ExportedAlbum.fromPhotokitAlbum(
      album: album2,
      folderId: folder1.id,
    )
    let exportedAlbum3 = try ExportedAlbum.fromPhotokitAlbum(
      album: album3,
      folderId: folder2.id,
    )

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
    let assetFiles = [
      assetFile1,
      assetFile2,
      assetFile3,
    ].sorted(by: { $0.assetId < $1.assetId })
    let exportedFolders = [
      ExportedFolder(
        id: Photokit.RootFolderId,
        name: "Untitled",
        parentId: nil,
      ),
      exportedFolder1,
      exportedFolder2,
    ].sorted(by: { $0.id < $1.id })
    let exportedAlbums = [
      exportedAlbum1,
      exportedAlbum2,
      exportedAlbum3,
    ].sorted(by: { $0.id < $1.id })

    let expectedInitialRes = ExportResult(
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
        folderInserted: 3,
        folderUpdated: 0,
        folderUnchanged: 0,
        albumInserted: 3,
        albumUpdated: 0,
        albumUnchanged: 0
      ),
      fileCopy: FileCopyResult(copied: 3, removed: 0)
    )

    // - MARK: Initial run
    let initialRes = try await self.photosExporterLib.export()
    #expect(initialRes == expectedInitialRes)

    let fileDirURL = exportBaseDirURL.appending(path: "files")
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
    ].sorted(by: { $0.assetId < $1.assetId })
    let sortedMockCopyCalls = self.photokitMock.copyResourceCalls
      .sorted(by: { $0.assetId < $1.assetId })
    #expect(
      sortedMockCopyCalls == expectedCopyCalls,
      "\(Diff.getDiffAsString(sortedMockCopyCalls, expectedCopyCalls) ?? "")"
    )

    let albumDirURL = exportBaseDirURL.appending(path: "albums")
    let expectedSymlinkCalls = [
      CreateSymlinkCall(
        src: fileDirURL
          .appending(path: exportedFile1.importedFileDir)
          .appending(path: exportedFile1.importedFileName),
        dest: albumDirURL
          .appending(path: FileHelper.normaliseForPath(exportedAlbum1.name))
          .appending(path: exportedFile1.importedFileName),
      ),
      CreateSymlinkCall(
        src: fileDirURL
          .appending(path: exportedFile2.importedFileDir)
          .appending(path: exportedFile2.importedFileName),
        dest: albumDirURL
          .appending(path: FileHelper.normaliseForPath(exportedFolder1.name))
          .appending(path: FileHelper.normaliseForPath(exportedAlbum2.name))
          .appending(path: exportedFile2.importedFileName),
      ),
      CreateSymlinkCall(
        src: fileDirURL
          .appending(path: exportedFile3.importedFileDir)
          .appending(path: exportedFile3.importedFileName),
        dest: albumDirURL
          .appending(path: FileHelper.normaliseForPath(exportedFolder1.name))
          .appending(path: FileHelper.normaliseForPath(exportedFolder2.name))
          .appending(path: FileHelper.normaliseForPath(exportedAlbum3.name))
          .appending(path: exportedFile3.importedFileName),
      ),
    ].sorted(by: { $0.src.absoluteString < $1.src.absoluteString })
    let sortedMockSymlinkCalls = fileManagerMock
      .createSymlinkCalls.sorted(by: { $0.src.absoluteString < $1.src.absoluteString })
    #expect(
      sortedMockSymlinkCalls == expectedSymlinkCalls,
      "\(Diff.getDiffAsString(sortedMockSymlinkCalls, expectedSymlinkCalls) ?? "")"
    )

    let assetsInDB = try exporterDB.getAllAssets().sorted(by: { $0.id < $1.id })
    // Avoid using Sets, because they use Hashable instead of Comparable
    #expect(
      assetsInDB == exportedAssets,
      "\(Diff.getDiffAsString(assetsInDB, exportedAssets) ?? "")"
    )

    let filesInDB = try exporterDB.getAllFiles().sorted(by: { $0.id < $1.id })
    #expect(
      filesInDB == exportedFiles,
      "\(Diff.getDiffAsString(filesInDB, exportedFiles) ?? "")"
    )

    let assetFilesInDB = try exporterDB.getAllAssetFiles().sorted(by: { $0.assetId < $1.assetId })
    #expect(
      assetFilesInDB == assetFiles,
      "\(Diff.getDiffAsString(assetFilesInDB, assetFiles) ?? "")"
    )

    let foldersInDB = try exporterDB.getAllFolders().sorted(by: { $0.id < $1.id })
    #expect(
      foldersInDB == exportedFolders,
      "\(Diff.getDiffAsString(foldersInDB, exportedFolders) ?? "")"
    )

    let albumsInDB = try exporterDB.getAllAlbums().sorted(by: { $0.id < $1.id })
    #expect(
      albumsInDB == exportedAlbums,
      "\(Diff.getDiffAsString(albumsInDB, exportedAlbums) ?? "")"
    )

    // - MARK: No change run
    let expectedNoChangeRes = ExportResult(
      assetExport: AssetExportResult(
        assetInserted: 0,
        assetUpdated: 0,
        assetUnchanged: 3,
        assetSkipped: 0,
        fileInserted: 0,
        fileUpdated: 0,
        fileUnchanged: 3,
        fileSkipped: 0
      ),
      collectionExport: CollectionExportResult(
        folderInserted: 0,
        folderUpdated: 0,
        folderUnchanged: 3,
        albumInserted: 0,
        albumUpdated: 0,
        albumUnchanged: 3
      ),
      fileCopy: FileCopyResult(copied: 0, removed: 0)
    )
    let noChangeRes = try await self.photosExporterLib.export()
    #expect(noChangeRes == expectedNoChangeRes)
    // Make sure no new file copy calls have happened
    #expect(photokitMock.copyResourceCalls.count == 3)
  }
}
