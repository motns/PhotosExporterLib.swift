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

@Suite("Photos Exporter Lib Tests")
// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
final class PhotosExporterLibTests {
  let photosExporterLib: PhotosExporterLib
  let exporterDB: ExporterDB
  var photokitMock: PhotokitMock
  var photosDBMock: PhotosDBMock
  let fileManagerMock: ExporterFileManagerMock
  let testDir: URL
  let timeProvider: TestTimeProvider
  let countryLookup: CachedLookupTable
  let cityLookup: CachedLookupTable
  let dataGen: TestDataGenerator

  init() async throws {
    var logger = Logger(label: "io.motns.testing")
    logger.logLevel = .critical
    // logger.logLevel = .debug
    self.testDir = try TestHelpers.createTestDir()

    self.photokitMock = PhotokitMock()
    self.photosDBMock = PhotosDBMock()
    self.fileManagerMock = ExporterFileManagerMock()
    self.timeProvider = TestTimeProvider()

    self.exporterDB = try ExporterDB(
      exportDBPath: testDir.appending(path: "testdb.sqlite"),
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
    if FileManager.default.fileExists(atPath: testDir.path(percentEncoded: false)) {
      try? FileManager.default.removeItem(atPath: testDir.path(percentEncoded: false))
    }
  }

  @Test("Export - Empty DB")
  // swiftlint:disable:next function_body_length
  func exportIntoEmptyDB() async throws {
    // - MARK: Set up test data
    let startTime = await timeProvider.freezeTime().getDate()
    let exportBaseDir = testDir

    let resource1 = dataGen.createPhotokitAssetResource()
    let resource2 = dataGen.createPhotokitAssetResource()
    let resource3 = dataGen.createPhotokitAssetResource()

    let asset1 = try dataGen.createPhotokitAsset(
      resources: [resource1],
    )
    let asset2 = try dataGen.createPhotokitAsset(
      resources: [resource2],
    )
    let asset3 = try dataGen.createPhotokitAsset(
      assetLibrary: .sharedAlbum,
      resources: [resource3],
    )

    await photokitMock.setAssets([asset1, asset2, asset3])

    await photosDBMock.setAssetLocations([
      asset1.id: dataGen.createPostalAddress(country: "United Kingdom", city: "London"),
      asset2.id: dataGen.createPostalAddress(country: "Spain", city: "Madrid"),
      // asset3 won't have location data
    ])

    await photosDBMock.setAssetScores([
      asset1.id: 902561736,
      asset2.id: 0,
    ])

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
    await photokitMock.setRootAlbums([album1])
    await photokitMock.setRootFolders([folder1])
    await photokitMock.setAlbums([album1, album2, album3])

    // - MARK: Create expected models
    let exportedAsset1 = ExportedAsset.fromPhotokitAsset(
      asset: asset1,
      aestheticScore: 902561736,
      now: startTime,
    )!
    let exportedFile1 = ExportedFile.fromPhotokitAssetResource(
      asset: asset1,
      resource: asset1.resources[0],
      now: startTime,
      countryId: try await countryLookup.getIdByName(name: "United Kingdom"),
      cityId: try await cityLookup.getIdByName(name: "London"),
      country: "United Kingdom",
      city: "London",
    )!.copy(wasCopied: true)
    let assetFile1 = ExportedAssetFile(
      assetId: exportedAsset1.id,
      fileId: exportedFile1.id,
      isDeleted: false,
      deletedAt: nil
    )

    let exportedAsset2 = ExportedAsset.fromPhotokitAsset(
      asset: asset2,
      aestheticScore: 0,
      now: startTime,
    )!
    let exportedFile2 = ExportedFile.fromPhotokitAssetResource(
      asset: asset2,
      resource: asset2.resources[0],
      now: startTime,
      countryId: try await countryLookup.getIdByName(name: "Spain"),
      cityId: try await cityLookup.getIdByName(name: "Madrid"),
      country: "Spain",
      city: "Madrid",
    )!.copy(wasCopied: true)
    let assetFile2 = ExportedAssetFile(
      assetId: exportedAsset2.id,
      fileId: exportedFile2.id,
      isDeleted: false,
      deletedAt: nil
    )

    let exportedAsset3 = ExportedAsset.fromPhotokitAsset(
      asset: asset3,
      aestheticScore: 0,
      now: startTime,
    )!
    let exportedFile3 = ExportedFile.fromPhotokitAssetResource(
      asset: asset3,
      resource: asset3.resources[0],
      now: startTime,
      countryId: nil,
      cityId: nil,
      country: nil,
      city: nil,
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

    // - MARK: Initial run
    var initialRes = PhotosExporterLib.Result.empty()
    for try await exporterStatus in photosExporterLib.exportWithProgress() {
      switch exporterStatus.status {
      case .complete(let res):
        initialRes = res
      default: break
      }
    }

    let expectedInitialRes = PhotosExporterLib.Result(
      assetExport: AssetExporterResult(
        assetInserted: 3,
        assetUpdated: 0,
        assetUnchanged: 0,
        assetSkipped: 0,
        assetMarkedForDeletion: 0,
        assetDeleted: 0,
        fileInserted: 3,
        fileUpdated: 0,
        fileUnchanged: 0,
        fileSkipped: 0,
        fileMarkedForDeletion: 0,
        fileDeleted: 0,
        runTime: initialRes.assetExport.runTime,
      ),
      collectionExport: CollectionExporterResult(
        folderInserted: 3,
        folderUpdated: 0,
        folderUnchanged: 0,
        folderDeleted: 0,
        albumInserted: 3,
        albumUpdated: 0,
        albumUnchanged: 0,
        albumDeleted: 0,
        runTime: initialRes.collectionExport.runTime,
      ),
      fileExport: FileExporterResult(
        copied: 3,
        deleted: 0,
        runTime: initialRes.fileExport.runTime,
      ),
      runTime: initialRes.runTime,
    )

    #expect(
      initialRes == expectedInitialRes,
      "\(initialRes.diff(expectedInitialRes).prettyDescription)"
    )

    let fileDirURL = exportBaseDir.appending(path: "files")
    let expectedCopyCalls = [
      CopyResourceCall(
        assetId: asset1.id,
        resourceType: asset1.resources[0].assetResourceType,
        originalFileName: asset1.resources[0].originalFileName,
        destination:
          fileDirURL
            .appending(path: exportedFile1.importedFileDir)
            .appending(path: exportedFile1.id),
      ),
      CopyResourceCall(
        assetId: asset2.id,
        resourceType: asset2.resources[0].assetResourceType,
        originalFileName: asset2.resources[0].originalFileName,
        destination:
          fileDirURL
            .appending(path: exportedFile2.importedFileDir)
            .appending(path: exportedFile2.id),
      ),
      CopyResourceCall(
        assetId: asset3.id,
        resourceType: asset3.resources[0].assetResourceType,
        originalFileName: asset3.resources[0].originalFileName,
        destination:
          fileDirURL
            .appending(path: exportedFile3.importedFileDir)
            .appending(path: exportedFile3.id),
      ),
    ].sorted(by: { $0.assetId < $1.assetId })
    let sortedMockCopyCalls = await self.photokitMock.copyResourceCalls
      .sorted(by: { $0.assetId < $1.assetId })
    #expect(
      sortedMockCopyCalls == expectedCopyCalls,
      "\(Diff.getDiff(sortedMockCopyCalls, expectedCopyCalls).prettyDescription)"
    )

    let albumDirURL = exportBaseDir.appending(path: "albums")
    let locationDirURL = exportBaseDir.appending(path: "locations")
    let topshotsDirURL = exportBaseDir.appending(path: "top-shots")
    let expectedSymlinkCalls = [
      // Album symlinks
      CreateSymlinkCall(
        src: fileDirURL
          .appending(path: exportedFile1.importedFileDir)
          .appending(path: exportedFile1.id),
        dest: albumDirURL
          .appending(path: FileHelper.normaliseForPath(exportedAlbum1.name))
          .appending(path: exportedFile1.id),
      ),
      CreateSymlinkCall(
        src: fileDirURL
          .appending(path: exportedFile2.importedFileDir)
          .appending(path: exportedFile2.id),
        dest: albumDirURL
          .appending(path: FileHelper.normaliseForPath(exportedFolder1.name))
          .appending(path: FileHelper.normaliseForPath(exportedAlbum2.name))
          .appending(path: exportedFile2.id),
      ),
      CreateSymlinkCall(
        src: fileDirURL
          .appending(path: exportedFile3.importedFileDir)
          .appending(path: exportedFile3.id),
        dest: albumDirURL
          .appending(path: FileHelper.normaliseForPath(exportedFolder1.name))
          .appending(path: FileHelper.normaliseForPath(exportedFolder2.name))
          .appending(path: FileHelper.normaliseForPath(exportedAlbum3.name))
          .appending(path: exportedFile3.id),
      ),
      // Location symlinks
      CreateSymlinkCall(
        src: fileDirURL
          .appending(path: exportedFile1.importedFileDir)
          .appending(path: exportedFile1.id),
        dest: locationDirURL
          .appending(path: FileHelper.normaliseForPath("United Kingdom"))
          .appending(path: FileHelper.normaliseForPath("London"))
          .appending(path: DateHelper.getYearStr(exportedAsset1.createdAt))
          .appending(path: DateHelper.getYearMonthStr(exportedAsset1.createdAt))
          .appending(path: exportedFile1.id),
      ),
      CreateSymlinkCall(
        src: fileDirURL
          .appending(path: exportedFile2.importedFileDir)
          .appending(path: exportedFile2.id),
        dest: locationDirURL
          .appending(path: FileHelper.normaliseForPath("Spain"))
          .appending(path: FileHelper.normaliseForPath("Madrid"))
          .appending(path: DateHelper.getYearStr(exportedAsset2.createdAt))
          .appending(path: DateHelper.getYearMonthStr(exportedAsset2.createdAt))
          .appending(path: exportedFile2.id),
      ),
      // Top shots symlinks
      CreateSymlinkCall(
        src: fileDirURL
          .appending(path: exportedFile1.importedFileDir)
          .appending(path: exportedFile1.id),
        dest: topshotsDirURL
          .appending(
            path: "\(exportedAsset1.aestheticScore)-\(exportedFile1.id)"
          ),
      ),
    ].sorted(by: { $0.dest.absoluteString < $1.dest.absoluteString })
    let sortedMockSymlinkCalls = await fileManagerMock
      .createSymlinkCalls.sorted(by: { $0.dest.absoluteString < $1.dest.absoluteString })
    #expect(
      sortedMockSymlinkCalls == expectedSymlinkCalls,
      "\(Diff.getDiff(sortedMockSymlinkCalls, expectedSymlinkCalls).prettyDescription)"
    )

    let assetsInDB = try exporterDB.getAllAssets().sorted(by: { $0.id < $1.id })
    #expect(
      assetsInDB == exportedAssets,
      "\(Diff.getDiff(assetsInDB, exportedAssets).prettyDescription)"
    )

    let filesInDB = try exporterDB.getAllFiles().sorted(by: { $0.id < $1.id })
    #expect(
      filesInDB == exportedFiles,
      "\(Diff.getDiff(filesInDB, exportedFiles).prettyDescription)"
    )

    let assetFilesInDB = try exporterDB.getAllAssetFiles().sorted(by: { $0.assetId < $1.assetId })
    #expect(
      assetFilesInDB == assetFiles,
      "\(Diff.getDiff(assetFilesInDB, assetFiles).prettyDescription)"
    )

    let foldersInDB = try exporterDB.getAllFolders().sorted(by: { $0.id < $1.id })
    #expect(
      foldersInDB == exportedFolders,
      "\(Diff.getDiff(foldersInDB, exportedFolders).prettyDescription)"
    )

    let albumsInDB = try exporterDB.getAllAlbums().sorted(by: { $0.id < $1.id })
    #expect(
      albumsInDB == exportedAlbums,
      "\(Diff.getDiff(albumsInDB, exportedAlbums).prettyDescription)"
    )

    let historyEntryInDBInitial = try photosExporterLib.lastRun()
    let expectedHistoryEntryInitial = HistoryEntry(
      id: historyEntryInDBInitial!.id,
      createdAt: await timeProvider.getDate(),
      exportResult: expectedInitialRes,
      assetCount: 3,
      fileCount: 3,
      albumCount: 3,
      folderCount: 3,
      fileSizeTotal: exportedFiles.reduce(0) { sum, curr in sum + curr.fileSize },
      runTime: historyEntryInDBInitial!.runTime,
    )

    #expect(
      historyEntryInDBInitial == expectedHistoryEntryInitial,
      "\(historyEntryInDBInitial?.diff(expectedHistoryEntryInitial).prettyDescription ?? "empty")",
    )

    // - MARK: No change run
    _ = await timeProvider.advanceTime(hours: 2)

    var noChangeRes = PhotosExporterLib.Result.empty()
    for try await exporterStatus in photosExporterLib.exportWithProgress() {
      switch exporterStatus.status {
      case .complete(let res):
        noChangeRes = res
      default: break
      }
    }

    let expectedNoChangeRes = PhotosExporterLib.Result(
      assetExport: AssetExporterResult(
        assetInserted: 0,
        assetUpdated: 0,
        assetUnchanged: 3,
        assetSkipped: 0,
        assetMarkedForDeletion: 0,
        assetDeleted: 0,
        fileInserted: 0,
        fileUpdated: 0,
        fileUnchanged: 3,
        fileSkipped: 0,
        fileMarkedForDeletion: 0,
        fileDeleted: 0,
        runTime: noChangeRes.assetExport.runTime,
      ),
      collectionExport: CollectionExporterResult(
        folderInserted: 0,
        folderUpdated: 0,
        folderUnchanged: 3,
        folderDeleted: 0,
        albumInserted: 0,
        albumUpdated: 0,
        albumUnchanged: 3,
        albumDeleted: 0,
        runTime: noChangeRes.collectionExport.runTime,
      ),
      fileExport: FileExporterResult(
        copied: 0,
        deleted: 0,
        runTime: noChangeRes.fileExport.runTime,
      ),
      runTime: noChangeRes.runTime,
    )

    #expect(
      noChangeRes == expectedNoChangeRes,
      "\(noChangeRes.diff(expectedNoChangeRes).prettyDescription)"
    )
    // Make sure no new file copy calls have happened
    #expect(await photokitMock.copyResourceCalls.count == 3)

    // - MARK: Update run
    _ = await timeProvider.advanceTime(hours: 2)

    let updatedAsset1 = asset1.copy(
      isFavourite: !asset1.isFavourite
    )
    await photokitMock.setAssets([updatedAsset1, asset2, asset3])

    await photosDBMock.setAssetLocations([
      asset1.id: dataGen.createPostalAddress(country: "United Kingdom", city: "London"),
      asset2.id: dataGen.createPostalAddress(country: "Hungary", city: "Budapest"),
    ])

    await photosDBMock.setAssetScores([
      asset1.id: 808547258,
      asset2.id: 0,
    ])

    let updatedAlbum1 = album1.copy(
      assetIds: [asset1.id, asset2.id]
    )
    await photokitMock.setRootAlbums([updatedAlbum1])
    await photokitMock.setAlbums([updatedAlbum1, album2, album3])

    let updatedExportedAsset1 = ExportedAsset.fromPhotokitAsset(
      asset: updatedAsset1,
      aestheticScore: 808547258,
      now: startTime,
    )!

    let updatedExportedAsset2 = ExportedAsset.fromPhotokitAsset(
      asset: asset2,
      aestheticScore: 0,
      now: startTime,
    )!
    let updatedExportedFile2 = ExportedFile.fromPhotokitAssetResource(
      asset: asset2,
      resource: asset2.resources[0],
      now: startTime,
      countryId: try await countryLookup.getIdByName(name: "Hungary"),
      cityId: try await cityLookup.getIdByName(name: "Budapest"),
      country: "Hungary",
      city: "Budapest",
    )!.copy(wasCopied: true)

    let updatedExportedAlbum1 = try ExportedAlbum.fromPhotokitAlbum(
      album: updatedAlbum1,
      folderId: Photokit.RootFolderId,
    )

    let updatedExportedAssets = [
      updatedExportedAsset1,
      updatedExportedAsset2,
      exportedAsset3,
    ].sorted(by: { $0.id < $1.id })
    let updatedExportedFiles = [
      exportedFile1,
      updatedExportedFile2,
      exportedFile3,
    ].sorted(by: { $0.id < $1.id })
    let updatedExportedAlbums = [
      updatedExportedAlbum1,
      exportedAlbum2,
      exportedAlbum3,
    ].sorted(by: { $0.id < $1.id })

    var updateRes = PhotosExporterLib.Result.empty()
    for try await exporterStatus in photosExporterLib.exportWithProgress() {
      switch exporterStatus.status {
      case .complete(let res):
        updateRes = res
      default: break
      }
    }

    let expectedUpdateRes = PhotosExporterLib.Result(
      assetExport: AssetExporterResult(
        assetInserted: 0,
        assetUpdated: 1,
        assetUnchanged: 2,
        assetSkipped: 0,
        assetMarkedForDeletion: 0,
        assetDeleted: 0,
        fileInserted: 0,
        fileUpdated: 1,
        fileUnchanged: 2,
        fileSkipped: 0,
        fileMarkedForDeletion: 0,
        fileDeleted: 0,
        runTime: updateRes.assetExport.runTime,
      ),
      collectionExport: CollectionExporterResult(
        folderInserted: 0,
        folderUpdated: 0,
        folderUnchanged: 3,
        folderDeleted: 0,
        albumInserted: 0,
        albumUpdated: 1,
        albumUnchanged: 2,
        albumDeleted: 0,
        runTime: updateRes.collectionExport.runTime,
      ),
      fileExport: FileExporterResult(
        copied: 1,
        deleted: 0,
        runTime: updateRes.fileExport.runTime,
      ),
      runTime: updateRes.runTime,
    )

    #expect(
      updateRes == expectedUpdateRes,
      "\(updateRes.diff(expectedUpdateRes).prettyDescription)"
    )

    let updatedAssetsInDB = try exporterDB.getAllAssets().sorted(by: { $0.id < $1.id })
    #expect(
      updatedAssetsInDB == updatedExportedAssets,
      "\(Diff.getDiff(updatedAssetsInDB, updatedExportedAssets).prettyDescription)"
    )

    let updatedFilesInDB = try exporterDB.getAllFiles().sorted(by: { $0.id < $1.id })
    #expect(
      updatedFilesInDB == updatedExportedFiles,
      "\(Diff.getDiff(updatedFilesInDB, updatedExportedFiles).prettyDescription)"
    )

    // Should be unchanged
    let assetFilesInDB2 = try exporterDB.getAllAssetFiles().sorted(by: { $0.assetId < $1.assetId })
    #expect(
      assetFilesInDB2 == assetFiles,
      "\(Diff.getDiff(assetFilesInDB2, assetFiles).prettyDescription)"
    )

    let updatedAlbumsInDB = try exporterDB.getAllAlbums().sorted(by: { $0.id < $1.id })
    #expect(
      updatedAlbumsInDB == updatedExportedAlbums,
      "\(Diff.getDiff(updatedAlbumsInDB, updatedExportedAlbums).prettyDescription)"
    )
  }

  // - MARK: Expire and Delete test
  @Test("Expire and Delete Assets and Files")
  // swiftlint:disable:next function_body_length cyclomatic_complexity
  func expireAndDeleteAssetsAndFiles() async throws {
    let now = await timeProvider.setTime(timeStr: "2025-04-05 12:05:30").getDate()
    let exportBaseDir = testDir

    // These will stay as-is
    let resource1 = dataGen.createPhotokitAssetResource()
    let resource2 = dataGen.createPhotokitAssetResource()
    let resourceForAssetToDeleteLater = dataGen.createPhotokitAssetResource()
    let resource4 = dataGen.createPhotokitAssetResource()
    // This will be deleted later
    let resourceToDeleteLater = dataGen.createPhotokitAssetResource()
    // Sixth Resource here has already been deleted

    let asset1 = try dataGen.createPhotokitAsset(
      resources: [resource1],
    )
    let asset2 = try dataGen.createPhotokitAsset(
      resources: [resource2],
    )
    let assetToDeleteLater = try dataGen.createPhotokitAsset(
      resources: [resourceForAssetToDeleteLater],
    )
    let asset3 = try dataGen.createPhotokitAsset(
      // One of these will be deleted later, one has already
      // been deleted
      resources: [resource4, resourceToDeleteLater],
    )
    // Fifth Asset has already been deleted

    await photokitMock.setAssets([
      asset1,
      asset2,
      assetToDeleteLater,
      asset3,
    ])

    let exportedAsset1 = try dataGen.createAndSaveExportedAsset(
      photokitAsset: asset1,
      aestheticScore: 0,
      now: now,
    )
    let exportedFile1 = try dataGen.createAndSaveExportedFile(
      photokitAsset: asset1,
      photokitResource: asset1.resources[0],
      now: now,
      country: nil,
      city: nil,
      wasCopied: true,
    )
    let assetFile1 = try dataGen.createAndSaveAssetFile(
      assetId: exportedAsset1.id,
      fileId: exportedFile1.id,
    )

    let exportedAsset2 = try dataGen.createAndSaveExportedAsset(
      photokitAsset: asset2,
      aestheticScore: 0,
      now: now,
    )
    let exportedFile2 = try dataGen.createAndSaveExportedFile(
      photokitAsset: asset2,
      photokitResource: asset2.resources[0],
      now: now,
      country: nil,
      city: nil,
      wasCopied: true,
    )
    let assetFile2 = try dataGen.createAndSaveAssetFile(
      assetId: exportedAsset2.id,
      fileId: exportedFile2.id,
    )

    let exportedAssetToDeleteLater = try dataGen.createAndSaveExportedAsset(
      photokitAsset: assetToDeleteLater,
      aestheticScore: 0,
      now: now,
    )
    let exportedFileToDeleteLaterAsset = try dataGen.createAndSaveExportedFile(
      photokitAsset: assetToDeleteLater,
      photokitResource: assetToDeleteLater.resources[0],
      now: now,
      country: nil,
      city: nil,
      wasCopied: true,
    )
    let assetFileToDeleteLaterAsset = try dataGen.createAndSaveAssetFile(
      assetId: exportedAssetToDeleteLater.id,
      fileId: exportedFileToDeleteLaterAsset.id,
    )

    let exportedAsset3 = try dataGen.createAndSaveExportedAsset(
      photokitAsset: asset3,
      aestheticScore: 0,
      now: now,
    )
    let exportedFile3 = try dataGen.createAndSaveExportedFile(
      photokitAsset: asset3,
      photokitResource: asset3.resources[0],
      now: now,
      country: nil,
      city: nil,
      wasCopied: true,
    )
    let exportedFileToDeleteLater = try dataGen.createAndSaveExportedFile(
      photokitAsset: asset3,
      photokitResource: asset3.resources[1],
      now: now,
      country: nil,
      city: nil,
      wasCopied: true,
    )
    let exportedFileDeleted = try dataGen.createAndSaveExportedFile(
      asset: exportedAsset3,
      wasCopied: true,
    )
    let assetFile3 = try dataGen.createAndSaveAssetFile(
      assetId: exportedAsset3.id,
      fileId: exportedFile3.id,
    )
    let assetFileToDeleteLaterFile = try dataGen.createAndSaveAssetFile(
      assetId: exportedAsset3.id,
      fileId: exportedFileToDeleteLater.id,
    )
    let assetFileDeleted = try dataGen.createAndSaveAssetFile(
      assetId: exportedAsset3.id,
      fileId: exportedFileDeleted.id,
    ).copy(
      isDeleted: true,
      deletedAt: now,
    )

    let exportedAssetDeleted = try dataGen.createAndSaveExportedAsset().copy(
      isDeleted: true,
      deletedAt: now,
    )
    let exportedFileForDeletedAsset = try dataGen.createAndSaveExportedFile(
      asset: exportedAssetDeleted,
      wasCopied: true,
    )
    let assetFileForDeletedAsset = try dataGen.createAndSaveAssetFile(
      assetId: exportedAssetDeleted.id,
      fileId: exportedFileForDeletedAsset.id,
    ).copy(
      isDeleted: true,
      deletedAt: now,
    )

    let exportedAssets = [
      exportedAsset1,
      exportedAsset2,
      exportedAssetToDeleteLater,
      exportedAsset3,
      exportedAssetDeleted,
    ].sorted { $0.id < $1.id }
    let exportedFiles = [
      exportedFile1,
      exportedFile2,
      exportedFileToDeleteLaterAsset,
      exportedFile3,
      exportedFileToDeleteLater,
      exportedFileDeleted,
      exportedFileForDeletedAsset,
    ].sorted { $0.id < $1.id }
    let assetFiles = [
      assetFile1,
      assetFile2,
      assetFileToDeleteLaterAsset,
      assetFile3,
      assetFileToDeleteLaterFile,
      assetFileDeleted,
      assetFileForDeletedAsset,
    ].sorted { $0.fileId < $1.fileId }

    // - MARK: First run - mark for deletion
    var markRes = PhotosExporterLib.Result.empty()
    for try await exporterStatus in photosExporterLib.exportWithProgress() {
      switch exporterStatus.status {
      case .complete(let res):
        markRes = res
      default: break
      }
    }

    let expectedMarkRes = PhotosExporterLib.Result(
      assetExport: AssetExporterResult(
        assetInserted: 0,
        assetUpdated: 0,
        assetUnchanged: 4,
        assetSkipped: 0,
        assetMarkedForDeletion: 1,
        assetDeleted: 0,
        fileInserted: 0,
        fileUpdated: 0,
        fileUnchanged: 5,
        fileSkipped: 0,
        fileMarkedForDeletion: 2,
        fileDeleted: 0,
        runTime: markRes.assetExport.runTime,
      ),
      collectionExport: CollectionExporterResult(
        folderInserted: 1,
        folderUpdated: 0,
        folderUnchanged: 0,
        folderDeleted: 0,
        albumInserted: 0,
        albumUpdated: 0,
        albumUnchanged: 0,
        albumDeleted: 0,
        runTime: markRes.collectionExport.runTime,
      ),
      fileExport: FileExporterResult(
        copied: 0,
        deleted: 0,
        runTime: markRes.fileExport.runTime,
      ),
      runTime: markRes.runTime,
    )

    #expect(
      markRes == expectedMarkRes,
      "\(markRes.diff(expectedMarkRes).prettyDescription)"
    )

    let assetsInDB = try exporterDB.getAllAssets().sorted(by: { $0.id < $1.id })
    #expect(
      assetsInDB == exportedAssets,
      "\(Diff.getDiff(assetsInDB, exportedAssets).prettyDescription)"
    )

    let filesInDB = try exporterDB.getAllFiles().sorted(by: { $0.id < $1.id })
    #expect(
      filesInDB == exportedFiles,
      "\(Diff.getDiff(filesInDB, exportedFiles).prettyDescription)"
    )

    let assetFilesInDB = try exporterDB.getAllAssetFiles().sorted(by: { $0.fileId < $1.fileId })
    #expect(
      assetFilesInDB == assetFiles,
      "\(Diff.getDiff(assetFilesInDB, assetFiles).prettyDescription)"
    )

    let historyEntryInDBMark = try photosExporterLib.lastRun()
    let expectedHistoryEntryMark = HistoryEntry(
      id: historyEntryInDBMark!.id,
      createdAt: await timeProvider.getDate(),
      exportResult: markRes,
      assetCount: 5,
      fileCount: 7,
      albumCount: 0,
      folderCount: 1,
      fileSizeTotal: exportedFiles.reduce(0) { sum, curr in sum + curr.fileSize },
      runTime: historyEntryInDBMark!.runTime,
    )

    #expect(
      historyEntryInDBMark == expectedHistoryEntryMark,
      "\(historyEntryInDBMark?.diff(expectedHistoryEntryMark).prettyDescription ?? "empty")",
    )

    // - MARK: Second run - no changes
    _ = await timeProvider.advanceTime(minutes: 10)

    var noChangeRes = PhotosExporterLib.Result.empty()
    for try await exporterStatus in photosExporterLib.exportWithProgress() {
      switch exporterStatus.status {
      case .complete(let res):
        noChangeRes = res
      default: break
      }
    }

    let expectedNoChange = PhotosExporterLib.Result(
      assetExport: AssetExporterResult(
        assetInserted: 0,
        assetUpdated: 0,
        assetUnchanged: 4,
        assetSkipped: 0,
        assetMarkedForDeletion: 0,
        assetDeleted: 0,
        fileInserted: 0,
        fileUpdated: 0,
        fileUnchanged: 5,
        fileSkipped: 0,
        fileMarkedForDeletion: 0,
        fileDeleted: 0,
        runTime: noChangeRes.assetExport.runTime,
      ),
      collectionExport: CollectionExporterResult(
        folderInserted: 0,
        folderUpdated: 0,
        folderUnchanged: 1,
        folderDeleted: 0,
        albumInserted: 0,
        albumUpdated: 0,
        albumUnchanged: 0,
        albumDeleted: 0,
        runTime: noChangeRes.collectionExport.runTime,
      ),
      fileExport: FileExporterResult(
        copied: 0,
        deleted: 0,
        runTime: noChangeRes.fileExport.runTime,
      ),
      runTime: noChangeRes.runTime,
    )

    #expect(
      noChangeRes == expectedNoChange,
      "\(noChangeRes.diff(expectedNoChange).prettyDescription)"
    )

    let historyEntryInDBNoChange = try photosExporterLib.lastRun()
    let expectedHistoryEntryNoChange = HistoryEntry(
      id: historyEntryInDBNoChange!.id,
      createdAt: await timeProvider.getDate(),
      exportResult: noChangeRes,
      assetCount: 5,
      fileCount: 7,
      albumCount: 0,
      folderCount: 1,
      fileSizeTotal: exportedFiles.reduce(0) { sum, curr in sum + curr.fileSize },
      runTime: historyEntryInDBNoChange!.runTime,
    )

    #expect(
      historyEntryInDBNoChange == expectedHistoryEntryNoChange,
      "\(historyEntryInDBNoChange?.diff(expectedHistoryEntryNoChange).prettyDescription ?? "empty")",
    )

    // - MARK: Third run - delete expired
    _ = await timeProvider.advanceTime(days: 31)

    var deleteRes = PhotosExporterLib.Result.empty()
    for try await exporterStatus in photosExporterLib.exportWithProgress() {
      switch exporterStatus.status {
      case .complete(let res):
        deleteRes = res
      default: break
      }
    }

    let expectedDelete = PhotosExporterLib.Result(
      assetExport: AssetExporterResult(
        assetInserted: 0,
        assetUpdated: 0,
        assetUnchanged: 4,
        assetSkipped: 0,
        assetMarkedForDeletion: 0,
        assetDeleted: 1,
        fileInserted: 0,
        fileUpdated: 0,
        fileUnchanged: 5,
        fileSkipped: 0,
        fileMarkedForDeletion: 0,
        fileDeleted: 2,
        runTime: deleteRes.assetExport.runTime,
      ),
      collectionExport: CollectionExporterResult(
        folderInserted: 0,
        folderUpdated: 0,
        folderUnchanged: 1,
        folderDeleted: 0,
        albumInserted: 0,
        albumUpdated: 0,
        albumUnchanged: 0,
        albumDeleted: 0,
        runTime: deleteRes.collectionExport.runTime,
      ),
      fileExport: FileExporterResult(
        copied: 0,
        deleted: 2,
        runTime: deleteRes.fileExport.runTime,
      ),
      runTime: deleteRes.runTime,
    )

    #expect(
      deleteRes == expectedDelete,
      "\(deleteRes.diff(expectedDelete).prettyDescription)"
    )

    let exportedAssetsAfterDelete = [
      exportedAsset1,
      exportedAsset2,
      exportedAssetToDeleteLater,
      exportedAsset3,
    ].sorted { $0.id < $1.id }
    let exportedFilesAfterDelete = [
      exportedFile1,
      exportedFile2,
      exportedFileToDeleteLaterAsset,
      exportedFile3,
      exportedFileToDeleteLater,
    ].sorted { $0.id < $1.id }
    let assetFilesAfterDelete = [
      assetFile1,
      assetFile2,
      assetFileToDeleteLaterAsset,
      assetFile3,
      assetFileToDeleteLaterFile,
    ].sorted { $0.fileId < $1.fileId }

    let assetsInDBAfterDelete = try exporterDB.getAllAssets().sorted(by: { $0.id < $1.id })
    #expect(
      assetsInDBAfterDelete == exportedAssetsAfterDelete,
      "\(Diff.getDiff(assetsInDBAfterDelete, exportedAssetsAfterDelete).prettyDescription)"
    )

    let filesInDBAfterDelete = try exporterDB.getAllFiles().sorted(by: { $0.id < $1.id })
    #expect(
      filesInDBAfterDelete == exportedFilesAfterDelete,
      "\(Diff.getDiff(filesInDBAfterDelete, exportedFilesAfterDelete).prettyDescription)"
    )

    let assetFilesInDBAfterDelete = try exporterDB.getAllAssetFiles().sorted(by: { $0.fileId < $1.fileId })
    #expect(
      assetFilesInDBAfterDelete == assetFilesAfterDelete,
      "\(Diff.getDiff(assetFilesInDBAfterDelete, assetFilesAfterDelete).prettyDescription)"
    )

    let historyEntryInDBDelete = try photosExporterLib.lastRun()
    let expectedHistoryEntryDelete = HistoryEntry(
      id: historyEntryInDBDelete!.id,
      createdAt: await timeProvider.getDate(),
      exportResult: deleteRes,
      assetCount: 4,
      fileCount: 5,
      albumCount: 0,
      folderCount: 1,
      fileSizeTotal: filesInDBAfterDelete.reduce(0) { sum, curr in sum + curr.fileSize },
      runTime: historyEntryInDBDelete!.runTime,
    )

    #expect(
      historyEntryInDBDelete == expectedHistoryEntryDelete,
      "\(historyEntryInDBDelete?.diff(expectedHistoryEntryDelete).prettyDescription ?? "empty")",
    )

    let fileDirURL = exportBaseDir.appending(path: "files")
    let expectedRemoveCalls = [
      RemoveCall(
        url: fileDirURL
          .appending(path: exportedFileDeleted.importedFileDir)
          .appending(path: exportedFileDeleted.id),
      ),
      RemoveCall(
        url: fileDirURL
          .appending(path: exportedFileForDeletedAsset.importedFileDir)
          .appending(path: exportedFileForDeletedAsset.id),
      ),
    ].sorted { $0.url.absoluteString < $1.url.absoluteString }

    let sortedFilteredRemoveCalls = await fileManagerMock.removeCalls
      .filter {
        // Remove calls will also include the ones made by the
        // Symlink creator Module, so we need to filter those out
        !$0.url.absoluteString.contains("album")
      }
      .sorted { $0.url.absoluteString < $1.url.absoluteString }
    #expect(
      sortedFilteredRemoveCalls == expectedRemoveCalls,
      "\(Diff.getDiff(sortedFilteredRemoveCalls, expectedRemoveCalls).prettyDescription)"
    )

    // - MARK: Fourth run - second expiry run
    _ = await timeProvider.advanceTime(days: 5)

    // Remove one Asset and One Resource from source
    await photokitMock.setAssets([
      asset1,
      asset2,
      asset3.copy(
        resources: [resource4],
      ),
    ])

    var markRes2 = PhotosExporterLib.Result.empty()
    for try await exporterStatus in photosExporterLib.exportWithProgress() {
      switch exporterStatus.status {
      case .complete(let res):
        markRes2 = res
      default: break
      }
    }

    let expectedMarkRes2 = PhotosExporterLib.Result(
      assetExport: AssetExporterResult(
        assetInserted: 0,
        assetUpdated: 0,
        assetUnchanged: 3,
        assetSkipped: 0,
        assetMarkedForDeletion: 1,
        assetDeleted: 0,
        fileInserted: 0,
        fileUpdated: 0,
        fileUnchanged: 3,
        fileSkipped: 0,
        fileMarkedForDeletion: 2,
        fileDeleted: 0,
        runTime: markRes2.assetExport.runTime,
      ),
      collectionExport: CollectionExporterResult(
        folderInserted: 0,
        folderUpdated: 0,
        folderUnchanged: 1,
        folderDeleted: 0,
        albumInserted: 0,
        albumUpdated: 0,
        albumUnchanged: 0,
        albumDeleted: 0,
        runTime: markRes2.collectionExport.runTime,
      ),
      fileExport: FileExporterResult(
        copied: 0,
        deleted: 0,
        runTime: markRes2.fileExport.runTime,
      ),
      runTime: markRes2.runTime,
    )

    #expect(
      markRes2 == expectedMarkRes2,
      "\(markRes2.diff(expectedMarkRes2).prettyDescription)",
    )

    let historyEntryInDBMark2 = try photosExporterLib.lastRun()
    let expectedHistoryEntryMark2 = HistoryEntry(
      id: historyEntryInDBMark2!.id,
      createdAt: await timeProvider.getDate(),
      exportResult: markRes2,
      assetCount: 4,
      fileCount: 5,
      albumCount: 0,
      folderCount: 1,
      fileSizeTotal: filesInDBAfterDelete.reduce(0) { sum, curr in sum + curr.fileSize },
      runTime: historyEntryInDBMark2!.runTime,
    )

    #expect(
      historyEntryInDBMark2 == expectedHistoryEntryMark2,
      "\(historyEntryInDBMark2?.diff(expectedHistoryEntryMark2).prettyDescription ?? "")",
    )

    // - MARK: Final run - second delete
    _ = await timeProvider.advanceTime(days: 31)
    await fileManagerMock.resetCalls()

    var deleteRes2 = PhotosExporterLib.Result.empty()
    for try await exporterStatus in photosExporterLib.exportWithProgress() {
      switch exporterStatus.status {
      case .complete(let res):
        deleteRes2 = res
      default: break
      }
    }

    let expectedDelete2 = PhotosExporterLib.Result(
      assetExport: AssetExporterResult(
        assetInserted: 0,
        assetUpdated: 0,
        assetUnchanged: 3,
        assetSkipped: 0,
        assetMarkedForDeletion: 0,
        assetDeleted: 1,
        fileInserted: 0,
        fileUpdated: 0,
        fileUnchanged: 3,
        fileSkipped: 0,
        fileMarkedForDeletion: 0,
        fileDeleted: 2,
        runTime: deleteRes2.assetExport.runTime,
      ),
      collectionExport: CollectionExporterResult(
        folderInserted: 0,
        folderUpdated: 0,
        folderUnchanged: 1,
        folderDeleted: 0,
        albumInserted: 0,
        albumUpdated: 0,
        albumUnchanged: 0,
        albumDeleted: 0,
        runTime: deleteRes2.collectionExport.runTime,
      ),
      fileExport: FileExporterResult(
        copied: 0,
        deleted: 2,
        runTime: deleteRes2.fileExport.runTime,
      ),
      runTime: deleteRes2.runTime,
    )

    #expect(
      deleteRes2 == expectedDelete2,
      "\(deleteRes2.diff(expectedDelete2).prettyDescription)"
    )

    let exportedAssetsAfterDelete2 = [
      exportedAsset1,
      exportedAsset2,
      exportedAsset3,
    ].sorted { $0.id < $1.id }
    let exportedFilesAfterDelete2 = [
      exportedFile1,
      exportedFile2,
      exportedFile3,
    ].sorted { $0.id < $1.id }
    let assetFilesAfterDelete2 = [
      assetFile1,
      assetFile2,
      assetFile3,
    ].sorted { $0.fileId < $1.fileId }

    let assetsInDBAfterDelete2 = try exporterDB.getAllAssets().sorted(by: { $0.id < $1.id })
    #expect(
      assetsInDBAfterDelete2 == exportedAssetsAfterDelete2,
      "\(Diff.getDiff(assetsInDBAfterDelete2, exportedAssetsAfterDelete2).prettyDescription)"
    )

    let filesInDBAfterDelete2 = try exporterDB.getAllFiles().sorted(by: { $0.id < $1.id })
    #expect(
      filesInDBAfterDelete2 == exportedFilesAfterDelete2,
      "\(Diff.getDiff(filesInDBAfterDelete2, exportedFilesAfterDelete2).prettyDescription)"
    )

    let assetFilesInDBAfterDelete2 = try exporterDB.getAllAssetFiles().sorted(by: { $0.fileId < $1.fileId })
    #expect(
      assetFilesInDBAfterDelete2 == assetFilesAfterDelete2,
      "\(Diff.getDiff(assetFilesInDBAfterDelete2, assetFilesAfterDelete2).prettyDescription)"
    )

    let historyEntryInDBDelete2 = try photosExporterLib.lastRun()
    let expectedHistoryEntryDelete2 = HistoryEntry(
      id: historyEntryInDBDelete2!.id,
      createdAt: await timeProvider.getDate(),
      exportResult: deleteRes2,
      assetCount: 3,
      fileCount: 3,
      albumCount: 0,
      folderCount: 1,
      fileSizeTotal: filesInDBAfterDelete2.reduce(0) { sum, curr in sum + curr.fileSize },
      runTime: historyEntryInDBDelete2!.runTime,
    )

    #expect(
      historyEntryInDBDelete2 == expectedHistoryEntryDelete2,
      "\(historyEntryInDBDelete2?.diff(expectedHistoryEntryDelete2).prettyDescription ?? "")",
    )

    let expectedRemoveCalls2 = [
      RemoveCall(
        url: fileDirURL
          .appending(path: exportedFileToDeleteLaterAsset.importedFileDir)
          .appending(path: exportedFileToDeleteLaterAsset.id),
      ),
      RemoveCall(
        url: fileDirURL
          .appending(path: exportedFileToDeleteLater.importedFileDir)
          .appending(path: exportedFileToDeleteLater.id),
      ),
    ].sorted { $0.url.absoluteString < $1.url.absoluteString }

    let sortedFilteredRemoveCalls2 = await fileManagerMock.removeCalls
      .filter {
        // Remove calls will also include the ones made by the
        // Symlink creator Module, so we need to filter those out
        !$0.url.absoluteString.contains("album")
      }
      .sorted { $0.url.absoluteString < $1.url.absoluteString }
    #expect(
      sortedFilteredRemoveCalls2 == expectedRemoveCalls2,
      "\(Diff.getDiff(sortedFilteredRemoveCalls2, expectedRemoveCalls2).prettyDescription)"
    )
  }

  // - MARK: Delete removed Albums and Folders
  @Test("Delete removed Albums and Folders")
  // swiftlint:disable:next function_body_length
  func deleteRemovedAlbumsAndFolders() async throws {
    let albumToKeep = dataGen.createPhotokitAlbum()
    let albumToRemove = dataGen.createPhotokitAlbum()
    let subfolderAlbumToKeep = dataGen.createPhotokitAlbum()
    let subfolderAlbumToRemove = dataGen.createPhotokitAlbum()

    var subfolderToKeep = dataGen.createPhotokitFolder(
      albums: [
        subfolderAlbumToKeep,
        subfolderAlbumToRemove,
      ]
    )
    let subfolderToRemove = dataGen.createPhotokitFolder()

    await photokitMock.setRootAlbums([albumToKeep, albumToRemove])
    await photokitMock.setRootFolders([subfolderToKeep, subfolderToRemove])
    await photokitMock.setAlbums([
      albumToKeep,
      albumToRemove,
      subfolderAlbumToKeep,
      subfolderAlbumToRemove,
    ])

    let initialRes = try await photosExporterLib.export()

    let expectedInitialRes = PhotosExporterLib.Result(
      assetExport: AssetExporterResult.empty().copy(
        runTime: initialRes.assetExport.runTime,
      ),
      collectionExport: CollectionExporterResult.empty().copy(
        folderInserted: 3,
        albumInserted: 4,
        runTime: initialRes.collectionExport.runTime,
      ),
      fileExport: FileExporterResult.empty().copy(
        runTime: initialRes.fileExport.runTime,
      ),
      runTime: initialRes.runTime
    )

    #expect(
      initialRes == expectedInitialRes,
      "\(initialRes.diff(expectedInitialRes).prettyDescription)"
    )

    subfolderToKeep = subfolderToKeep.copy(
      albums: [subfolderAlbumToKeep]
    )

    await photokitMock.setRootAlbums([albumToKeep])
    await photokitMock.setRootFolders([subfolderToKeep])
    await photokitMock.setAlbums([
      albumToKeep,
      subfolderAlbumToKeep,
    ])

    let removeRes = try await photosExporterLib.export()

    let expectedRemoveRes = PhotosExporterLib.Result(
      assetExport: AssetExporterResult.empty().copy(
        runTime: removeRes.assetExport.runTime,
      ),
      collectionExport: CollectionExporterResult.empty().copy(
        folderUnchanged: 2,
        folderDeleted: 1,
        albumUnchanged: 2,
        albumDeleted: 2,
        runTime: removeRes.collectionExport.runTime,
      ),
      fileExport: FileExporterResult.empty().copy(
        runTime: removeRes.fileExport.runTime,
      ),
      runTime: removeRes.runTime
    )

    #expect(
      removeRes == expectedRemoveRes,
      "\(removeRes.diff(expectedRemoveRes).prettyDescription)"
    )

    let expectedAlbumIds = Set([
      albumToKeep.id,
      subfolderAlbumToKeep.id,
    ])
    let exportedAlbumIds = try exporterDB.getAlbumIdSet()
    #expect(expectedAlbumIds == exportedAlbumIds)

    let expectedFolderIds = Set([
      Photokit.RootFolderId,
      subfolderToKeep.id,
    ])
    let exportedFolderIds = try exporterDB.getFolderIdSet()
    #expect(expectedFolderIds == exportedFolderIds)
  }
}
