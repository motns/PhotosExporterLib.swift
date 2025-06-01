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

@Suite("Exporter DB tests")
// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
final class ExporterDBTests {
  let testDir: String
  let exporterDB: ExporterDB
  let testTimeProvider: TestTimeProvider
  let dataGen: TestDataGenerator

  init() throws {
    self.testDir = try TestHelpers.createTestDir()
    let dbPath = testDir + "/testdb.sqlite"
    var logger = Logger(label: "io.motns.testing")
    logger.logLevel = .critical
    self.testTimeProvider = TestTimeProvider()
    self.exporterDB = try ExporterDB(
      exportDBPath: dbPath,
      logger: logger,
    )
    self.dataGen = TestDataGenerator(exporterDB: self.exporterDB)
  }

  deinit {
    if FileManager.default.fileExists(atPath: testDir) {
      try? FileManager.default.removeItem(atPath: testDir)
    }
  }

  @Test("Count Assets")
  func countAssets() throws {
    try (1...15).forEach { _ in
      _ = try dataGen.createAndSaveExportedAsset()
    }

    let res = try exporterDB.countAssets()
    #expect(res == 15)
  }

  @Test("Count Files")
  func countFiles() throws {
    try (1...12).forEach { _ in
      _ = try dataGen.createAndSaveLinkedFile()
    }

    let res = try exporterDB.countFiles()
    #expect(res == 12)
  }

  @Test("Count Albums")
  func countAlbums() throws {
    let folder = try dataGen.createAndSaveExportedFolder()
    try (1...9).forEach { _ in
      _ = try dataGen.createAndSaveExportedAlbum(
        albumFolderId: folder.id
      )
    }

    let res = try exporterDB.countAlbums()
    #expect(res == 9)
  }

  @Test("Count Folders")
  func countFolders() throws {
    try (1...7).forEach { _ in
      _ = try dataGen.createAndSaveExportedFolder()
    }

    let res = try exporterDB.countFolders()
    #expect(res == 7)
  }

  @Test("Get Asset ID Set")
  func getAssetIdSet() throws {
    let asset1 = try dataGen.createAndSaveExportedAsset()
    let asset2 = try dataGen.createAndSaveExportedAsset()
    let asset3 = try dataGen.createAndSaveExportedAsset()
    // Assets marked as deleted should not show up in results
    let asset4 = try dataGen.createExportedAsset(isDeleted: true)
    _ = try exporterDB.upsertAsset(asset: asset4)

    let expected = Set([asset1.id, asset2.id, asset3.id])
    let result = try exporterDB.getAssetIdSet()
    #expect(result == expected)
  }

  @Test("Get File ID Set")
  func getFileIdSet() throws {
    let (_, file1, _) = try dataGen.createAndSaveLinkedFile()
    let (_, file2, _) = try dataGen.createAndSaveLinkedFile()
    let (_, file3, _) = try dataGen.createAndSaveLinkedFile()
    // Files with Asset File marked as deleted
    let (_, _, assetFile4) = try dataGen.createAndSaveLinkedFile()
    _ = try exporterDB.upsertAssetFile(
      assetFile: assetFile4.copy(isDeleted: true)
    )

    let expected = Set([file1.id, file2.id, file3.id])
    let result = try exporterDB.getFileIdSet()
    #expect(result == expected)
  }

  @Test("Get Albums in Folder")
  func getAlbumsInFolder() throws {
    let parentFolder = ExportedFolder(
      id: UUID().uuidString,
      name: "Parent Folder",
      parentId: nil
    )
    _ = try exporterDB.upsertFolder(folder: parentFolder)

    let album1 = ExportedAlbum(
      id: UUID().uuidString,
      albumType: .user,
      albumFolderId: parentFolder.id,
      name: "Album 1",
      assetIds: []
    )
    let album2 = ExportedAlbum(
      id: UUID().uuidString,
      albumType: .user,
      albumFolderId: parentFolder.id,
      name: "Album 2",
      assetIds: []
    )
    _ = try exporterDB.upsertAlbum(album: album1)
    _ = try exporterDB.upsertAlbum(album: album2)

    let res = try exporterDB.getAlbumsInFolder(folderId: parentFolder.id)
    #expect(Set(res) == Set([album1, album2]))
  }

  @Test("Get orphaned Files")
  func getOrphanedFiles() throws {
    _ = try dataGen.createAndSaveLinkedFile()
    _ = try dataGen.createAndSaveLinkedFile()
    let asset3 = try dataGen.createAndSaveExportedAsset()
    let asset4 = try dataGen.createAndSaveExportedAsset()
    let file3 = try dataGen.createAndSaveExportedFile(asset: asset3)
    let file4 = try dataGen.createAndSaveExportedFile(asset: asset4)

    let res = try exporterDB.getOrphanedFiles()
      .sorted(by: { $0.id < $1.id })
    let expected = [file3, file4].sorted(by: { $0.id < $1.id })
    #expect(
      res == expected,
      "\(Diff.getDiffAsString(res, expected) ?? "")"
    )
  }

  @Test("Get files with location")
  func getFilesWithLocation() throws {
    let asset1 = try dataGen.createAndSaveExportedAsset(
      createdAt: TestHelpers.dateFromStr("2025-03-01 12:00:00"),
      city: "Madrid",
      country: "Spain",
    )
    let file1 = try dataGen.createAndSaveExportedFile(asset: asset1)
    _ = try dataGen.createAndSaveAssetFile(assetId: asset1.id, fileId: file1.id)

    let asset2 = try dataGen.createAndSaveExportedAsset(
      createdAt: TestHelpers.dateFromStr("2025-03-02 12:00:00"),
      city: "London",
      country: "United Kingdom",
    )
    // Have two Assets point to the same file, to test the grouping in the query
    let asset3 = try dataGen.createAndSaveExportedAsset(
      createdAt: TestHelpers.dateFromStr("2025-03-03 12:00:00"),
      city: "London",
      country: "United Kingdom",
    )
    let file2 = try dataGen.createAndSaveExportedFile(asset: asset2)
    _ = try dataGen.createAndSaveAssetFile(assetId: asset2.id, fileId: file2.id)
    _ = try dataGen.createAndSaveAssetFile(assetId: asset3.id, fileId: file2.id)

    let asset4 = try dataGen.createAndSaveExportedAsset(
      createdAt: TestHelpers.dateFromStr("2025-03-01 12:00:00"),
    )
    let file3 = try dataGen.createAndSaveExportedFile(asset: asset4)
    _ = try dataGen.createAndSaveAssetFile(assetId: asset4.id, fileId: file3.id)

    let filesWithLocation = try exporterDB.getFilesWithLocation()
      .sorted { $0.exportedFile.id < $1.exportedFile.id }
    let expected = [
      ExportedFileWithLocation(
        exportedFile: file1,
        createdAt: asset1.createdAt,
        country: "Spain",
        city: "Madrid",
      ),
      ExportedFileWithLocation(
        exportedFile: file2,
        createdAt: asset2.createdAt,
        country: "United Kingdom",
        city: "London",
      ),
    ].sorted { $0.exportedFile.id < $1.exportedFile.id }

    #expect(
      filesWithLocation == expected,
      "\(Diff.getDiffAsString(filesWithLocation, expected) ?? "")",
    )
  }

  @Test("Get files with score")
  func getFilesWithScore() throws {
    // Above threshold
    let asset1 = try dataGen.createAndSaveExportedAsset(
      aestheticScore: 910000000
    )
    let file1 = try dataGen.createAndSaveExportedFile(asset: asset1)
    _ = try dataGen.createAndSaveAssetFile(assetId: asset1.id, fileId: file1.id)

    // On threshold
    let asset2 = try dataGen.createAndSaveExportedAsset(
      aestheticScore: 900000000
    )
    let file2 = try dataGen.createAndSaveExportedFile(asset: asset2)
    _ = try dataGen.createAndSaveAssetFile(assetId: asset2.id, fileId: file2.id)

    // Below threshold
    let asset3 = try dataGen.createAndSaveExportedAsset(
      aestheticScore: 700000000
    )
    let file3 = try dataGen.createAndSaveExportedFile(asset: asset3)
    _ = try dataGen.createAndSaveAssetFile(assetId: asset3.id, fileId: file3.id)

    let filesWithScore = try exporterDB.getFilesWithScore(
      threshold: 900000000
    ).sorted { $0.exportedFile.id < $1.exportedFile.id }
    let expected = [
      ExportedFileWithScore(
        exportedFile: file1,
        score: 910000000
      ),
      ExportedFileWithScore(
        exportedFile: file2,
        score: 900000000
      ),
    ].sorted { $0.exportedFile.id < $1.exportedFile.id }

    #expect(
      filesWithScore == expected,
      "\(Diff.getDiffAsString(filesWithScore, expected) ?? "")",
    )
  }

  @Test("Get Files with AssetIdsToCopy")
  func getFilesWithAssetIdsToCopy() throws {
    let (asset1, file1, _) = try dataGen.createAndSaveLinkedFile()
    let (asset2, file2, _) = try dataGen.createAndSaveLinkedFile()

    let file3 = dataGen.createExportedFile(asset: asset2).copy(
      wasCopied: true
    )
    _ = try exporterDB.upsertFile(file: file3)
    _ = try dataGen.createAndSaveAssetFile(assetId: asset2.id, fileId: file3.id)

    let fileWithAssetIds1 = ExportedFileWithAssetIds(
      exportedFile: file1,
      assetIds: [asset1.id]
    )
    let fileWithAssetIds2 = ExportedFileWithAssetIds(
      exportedFile: file2,
      assetIds: [asset2.id]
    )

    let toCopy = try exporterDB.getFilesWithAssetIdsToCopy()
    #expect(Set(toCopy) == Set([fileWithAssetIds1, fileWithAssetIds2]))
  }

  @Test("Get Files for Album")
  func getFilesForAlbum() throws {
    let asset1 = try dataGen.createExportedAsset()
    _ = try self.exporterDB.upsertAsset(asset: asset1)
    let file1 = dataGen.createExportedFile(asset: asset1, city: "London", country: "United Kingdom")
    _ = try self.exporterDB.upsertFile(file: file1)
    _ = try self.exporterDB.upsertAssetFile(assetFile: ExportedAssetFile(
      assetId: asset1.id,
      fileId: file1.id,
      isDeleted: false,
      deletedAt: nil,
    ))

    let asset2 = try dataGen.createExportedAsset()
    _ = try self.exporterDB.upsertAsset(asset: asset2)
    let file2 = dataGen.createExportedFile(asset: asset2, city: "Madrid", country: "Spain")
    _ = try self.exporterDB.upsertFile(file: file2)
    _ = try self.exporterDB.upsertAssetFile(assetFile: ExportedAssetFile(
      assetId: asset2.id,
      fileId: file2.id,
      isDeleted: false,
      deletedAt: nil,
    ))

    let asset3 = try dataGen.createExportedAsset()
    _ = try self.exporterDB.upsertAsset(asset: asset3)
    let file3 = dataGen.createExportedFile(asset: asset3, city: "Budapest", country: "Hungary")
    _ = try self.exporterDB.upsertFile(file: file3)
    _ = try self.exporterDB.upsertAssetFile(assetFile: ExportedAssetFile(
      assetId: asset3.id,
      fileId: file3.id,
      isDeleted: false,
      deletedAt: nil,
    ))

    let newFolder = ExportedFolder(
      id: UUID().uuidString,
      name: "My Folder",
      parentId: nil
    )
    _ = try self.exporterDB.upsertFolder(folder: newFolder)

    let newAlbum = ExportedAlbum(
      id: UUID().uuidString,
      albumType: .user,
      albumFolderId: newFolder.id,
      name: "My Album",
      assetIds: [
        asset1.id,
        asset2.id,
        asset3.id,
      ]
    )
    _ = try self.exporterDB.upsertAlbum(album: newAlbum)

    let filesForAlbum = try self.exporterDB.getFilesForAlbum(albumId: newAlbum.id)
    #expect(Set(filesForAlbum) == Set([file1, file2, file3]))
  }

  @Test("Get Folders with Parent")
  func getFoldersWithParent() throws {
    let parentFolder = ExportedFolder(
      id: UUID().uuidString,
      name: "Parent Folder",
      parentId: nil
    )
    _ = try exporterDB.upsertFolder(folder: parentFolder)

    let childFolder1 = ExportedFolder(
      id: UUID().uuidString,
      name: "Child Folder 1",
      parentId: parentFolder.id
    )
    let childFolder2 = ExportedFolder(
      id: UUID().uuidString,
      name: "Child Folder 2",
      parentId: parentFolder.id
    )
    _ = try exporterDB.upsertFolder(folder: childFolder1)
    _ = try exporterDB.upsertFolder(folder: childFolder2)

    let res = try exporterDB.getFoldersWithParent(parentId: parentFolder.id)
    #expect(Set(res) == Set([childFolder1, childFolder2]))
  }

  @Test("Upsert Asset - New")
  func upsertAssetNew() throws {
    let newAsset = try dataGen.createExportedAsset()
    let insertRes = try self.exporterDB.upsertAsset(asset: newAsset)
    #expect(insertRes == UpsertResult.insert)

    let insertedAsset = try? exporterDB.getAsset(id: newAsset.id)
    #expect(insertedAsset == newAsset)
  }

  @Test("Upsert Asset - Update")
  func upsertAssetUpdate() throws {
    let asset = try dataGen.createExportedAsset(
      isFavourite: false
    )

    let insertRes = try self.exporterDB.upsertAsset(asset: asset)
    #expect(insertRes == UpsertResult.insert)

    let updated = asset.copy(isFavourite: true)
    let updateRes = try self.exporterDB.upsertAsset(asset: updated)
    #expect(updateRes == UpsertResult.update)

    let updatedAsset = try? exporterDB.getAsset(id: asset.id)
    let updatedToCheck = updated.copy(updatedAt: updatedAsset?.updatedAt)
    #expect(updatedAsset == updatedToCheck)
  }

  @Test("Upsert File - New")
  func upsertFileNew() throws {
    let city = "London"
    let country = "United Kingdom"
    let asset = try dataGen.createExportedAsset(city: city, country: country)
    _ = try self.exporterDB.upsertAsset(asset: asset)

    let newFile = dataGen.createExportedFile(asset: asset, city: city, country: country)
    let insertRes = try self.exporterDB.upsertFile(file: newFile)
    #expect(insertRes == UpsertResult.insert)

    let duplicateRes = try self.exporterDB.upsertFile(file: newFile)
    #expect(duplicateRes == UpsertResult.nochange)

    let insertedFile = try? exporterDB.getFile(id: newFile.id)
    #expect(insertedFile == newFile)
  }

  @Test("Upsert File - Update")
  func upsertFileUpdate() throws {
    let city = "London"
    let country = "United Kingdom"
    let asset = try dataGen.createExportedAsset(city: city, country: country)
    _ = try self.exporterDB.upsertAsset(asset: asset)

    let newFile = dataGen.createExportedFile(asset: asset, city: city, country: country)
    let insertRes = try self.exporterDB.upsertFile(file: newFile)
    #expect(insertRes == UpsertResult.insert)

    let updatedFile = newFile.copy(wasCopied: true)
    _ = try exporterDB.upsertFile(file: updatedFile)

    let updatedToCheck = try? exporterDB.getFile(id: newFile.id)
    #expect(updatedToCheck == updatedFile)
  }

  @Test("Upsert Asset File - New")
  func upsertAssetFileNew() throws {
    let asset = try dataGen.createExportedAsset()
    let file = dataGen.createExportedFile(asset: asset)
    _ = try exporterDB.upsertAsset(asset: asset)
    _ = try exporterDB.upsertFile(file: file)

    let newAssetFile = ExportedAssetFile(
      assetId: asset.id,
      fileId: file.id,
      isDeleted: false,
      deletedAt: nil
    )
    let insertRes = try exporterDB.upsertAssetFile(assetFile: newAssetFile)
    #expect(insertRes == .insert)

    let duplicateRes = try exporterDB.upsertAssetFile(assetFile: newAssetFile)
    #expect(duplicateRes == .nochange)

    let inserted = try? exporterDB.getAssetFile(assetId: asset.id, fileId: file.id)
    #expect(inserted == newAssetFile)
  }

  @Test("Upsert Asset File - Updated")
  func upsertAssetFileUpdated() throws {
    let asset = try dataGen.createExportedAsset()
    let file = dataGen.createExportedFile(asset: asset)
    _ = try exporterDB.upsertAsset(asset: asset)
    _ = try exporterDB.upsertFile(file: file)

    let newAssetFile = ExportedAssetFile(
      assetId: asset.id,
      fileId: file.id,
      isDeleted: false,
      deletedAt: nil
    )
    let insertRes = try exporterDB.upsertAssetFile(assetFile: newAssetFile)
    #expect(insertRes == .insert)

    let updated = newAssetFile.copy(
      isDeleted: true,
      deletedAt: TestHelpers.dateFromStr("2025-05-15 11:30:05")!,
    )
    let updateRes = try exporterDB.upsertAssetFile(assetFile: updated)
    #expect(updateRes == .update)

    let toCheck = try? exporterDB.getAssetFile(assetId: asset.id, fileId: file.id)
    #expect(toCheck == updated)
  }

  @Test("Upsert Folder - New")
  func upsertFolderNew() throws {
    let newFolder = ExportedFolder(
      id: UUID().uuidString,
      name: "New Folder",
      parentId: nil
    )
    let res = try self.exporterDB.upsertFolder(folder: newFolder)
    #expect(res == UpsertResult.insert)

    let folderToCheck = try self.exporterDB.getFolder(id: newFolder.id)
    #expect(folderToCheck == newFolder)
  }

  @Test("Upsert Folder - Update")
  func upsertFolderUpdate() throws {
    let newFolder = ExportedFolder(
      id: UUID().uuidString,
      name: "My Folder",
      parentId: nil
    )
    let insertRes = try self.exporterDB.upsertFolder(folder: newFolder)
    #expect(insertRes == UpsertResult.insert)

    let updatedFolder = newFolder.copy(name: "New Name")
    let updatedRes = try self.exporterDB.upsertFolder(folder: updatedFolder)
    #expect(updatedRes == UpsertResult.update)

    let folderToCheck = try self.exporterDB.getFolder(id: newFolder.id)
    #expect(folderToCheck == updatedFolder)
  }

  @Test("Upsert Album - New")
  func upsertAlbumNew() throws {
    let newFolder = ExportedFolder(
      id: UUID().uuidString,
      name: "My Folder",
      parentId: nil
    )
    _ = try self.exporterDB.upsertFolder(folder: newFolder)

    let newAlbum = ExportedAlbum(
      id: UUID().uuidString,
      albumType: .user,
      albumFolderId: newFolder.id,
      name: "My Album",
      assetIds: [
        UUID().uuidString,
        UUID().uuidString,
        UUID().uuidString,
      ]
    )

    let insertRes = try self.exporterDB.upsertAlbum(album: newAlbum)
    #expect(insertRes == UpsertResult.insert)

    let albumToCheck = try self.exporterDB.getAlbum(id: newAlbum.id)
    #expect(albumToCheck == newAlbum)
  }

  @Test("Upsert Album - Update")
  func upsertAlbumUpdate() throws {
    let newFolder = ExportedFolder(
      id: UUID().uuidString,
      name: "My Folder",
      parentId: nil
    )
    _ = try self.exporterDB.upsertFolder(folder: newFolder)

    let newAlbum = ExportedAlbum(
      id: UUID().uuidString,
      albumType: .user,
      albumFolderId: newFolder.id,
      name: "My Album",
      assetIds: [
        UUID().uuidString,
        UUID().uuidString,
        UUID().uuidString,
      ]
    )
    let insertRes = try self.exporterDB.upsertAlbum(album: newAlbum)
    #expect(insertRes == UpsertResult.insert)

    let updatedAlbum = newAlbum.copy(
      name: "Best Photos"
    )
    let updateRes = try self.exporterDB.upsertAlbum(album: updatedAlbum)
    #expect(updateRes == UpsertResult.update)
    let nochangeRes = try self.exporterDB.upsertAlbum(album: updatedAlbum)
    #expect(nochangeRes == UpsertResult.nochange)

    let albumToCheck = try self.exporterDB.getAlbum(id: newAlbum.id)
    #expect(albumToCheck == updatedAlbum)
  }

  @Test("Mark Asset as Deleted")
  func markAssetAsDeleted() throws {
    let (asset, _, _) = try dataGen.createAndSaveLinkedFile()
    let now = TestHelpers.dateFromStr("2025-05-20 11:30:05")
    _ = try exporterDB.markAssetAsDeleted(id: asset.id, now: now)

    let updated = try exporterDB.getAsset(id: asset.id)
    #expect(updated?.isDeleted == true)
    #expect(updated?.deletedAt == now)
  }

  @Test("Remove expired Assets")
  func removeExpiredAssets() throws {
    let asset1 = try dataGen.createAndSaveExportedAsset()
    _ = try dataGen.createAndSaveExportedAsset(
      isDeleted: true,
      deletedAt: TestHelpers.dateFromStr("2025-04-01 12:00:00")!,
    )
    let asset3 = try dataGen.createAndSaveExportedAsset(
      isDeleted: true,
      deletedAt: TestHelpers.dateFromStr("2025-05-01 12:00:00")!,
    )

    _ = try exporterDB.deleteExpiredAssets(
      cutoffDate: TestHelpers.dateFromStr("2025-04-15 12:00:00")!
    )

    let assets = try exporterDB.getAllAssets()
      .sorted(by: { $0.id < $1.id })
    let expected = [asset1, asset3].sorted(by: { $0.id < $1.id })
    #expect(
      assets == expected,
      "\(Diff.getDiffAsString(assets, expected) ?? "")",
    )
  }

  @Test("Mark File as Copied")
  func markFileAsCopied() throws {
    let (_, file1, _) = try dataGen.createAndSaveLinkedFile()
    let (_, file2, _) = try dataGen.createAndSaveLinkedFile()

    try exporterDB.markFileAsCopied(id: file1.id)

    let copiedFile = try exporterDB.getFile(id: file1.id)
    #expect(copiedFile?.wasCopied == true)

    let nonCopiedFile = try exporterDB.getFile(id: file2.id)
    #expect(nonCopiedFile?.wasCopied == false)
  }

  @Test("Mark File as Deleted")
  func markFileAsDeleted() throws {
    let (asset, file, _) = try dataGen.createAndSaveLinkedFile()
    let now = TestHelpers.dateFromStr("2025-05-20 11:30:05")
    _ = try exporterDB.markFileAsDeleted(id: file.id, now: now)

    let updated = try exporterDB.getAssetFile(assetId: asset.id, fileId: file.id)
    #expect(updated?.isDeleted == true)
    #expect(updated?.deletedAt == now)
  }

  @Test("Remove expired Files")
  func removeExpiredFiles() throws {
    let asset1 = try dataGen.createAndSaveExportedAsset()
    let asset2 = try dataGen.createAndSaveExportedAsset()
    let asset3 = try dataGen.createAndSaveExportedAsset()

    let file1 = try dataGen.createAndSaveExportedFile(asset: asset1)
    let file2 = try dataGen.createAndSaveExportedFile(asset: asset2)
    let file3 = try dataGen.createAndSaveExportedFile(asset: asset3)

    let assetFile1 = try dataGen.createAndSaveAssetFile(
      assetId: asset1.id,
      fileId: file1.id,
      isDeleted: false,
      deletedAt: nil
    )
    // This should be deleted based on cutoff date
    _ = try dataGen.createAndSaveAssetFile(
      assetId: asset2.id,
      fileId: file2.id,
      isDeleted: true,
      deletedAt: TestHelpers.dateFromStr("2025-04-01 12:00:00")!
    )
    // This should be left alone based on cutoff date
    let assetFile3 = try dataGen.createAndSaveAssetFile(
      assetId: asset3.id,
      fileId: file3.id,
      isDeleted: true,
      deletedAt: TestHelpers.dateFromStr("2025-05-01 12:00:00")!
    )

    _ = try exporterDB.deleteExpiredAssetFiles(
      cutoffDate: TestHelpers.dateFromStr("2025-04-15 12:00:00")!
    )

    let assetFiles = try exporterDB.getAllAssetFiles()
      .sorted(by: { $0.assetId < $1.assetId })
    let expected = [assetFile1, assetFile3].sorted(by: { $0.assetId < $1.assetId })
    #expect(
      assetFiles == expected,
      "\(Diff.getDiffAsString(assetFiles, expected) ?? "")",
    )
  }

  @Test("Delete File")
  func deleteFile() throws {
    let asset = try dataGen.createAndSaveExportedAsset()
    let file = try dataGen.createAndSaveExportedFile(asset: asset)

    _ = try exporterDB.deleteFile(id: file.id)
    #expect(try exporterDB.getFile(id: file.id) == nil)
  }

  @Test("Insert Export Result History Entry")
  func insertExportResultHistoryEntry() throws {
    let now = testTimeProvider.getDate()
    let entry = dataGen.createExportResultHistoryEntry(now: now)

    try exporterDB.insertExportResultHistoryEntry(entry: entry)
    let entryInDB = try exporterDB.getExportResultHistoryEntry(id: entry.id)
    #expect(
      entryInDB == entry,
      "\(entryInDB?.getDiffAsString(entry) ?? "")"
    )
  }

  @Test("Get Latest Export Result History Entry")
  func getLatestExportResultHistoryEntry() throws {
    let entries = try (0...5).map { _ in
      try dataGen.createAndSaveExportResultHistoryEntry()
    }.sorted { $1.createdAt < $0.createdAt }
    let latestEntry = entries.first!

    let latestEntryInDB = try exporterDB.getLatestExportResultHistoryEntry()
    #expect(
      latestEntryInDB == latestEntry,
      "\(latestEntryInDB?.getDiffAsString(latestEntry) ?? "")"
    )
  }

  @Test("Get Export Result History Entry list")
  func getExportResultHistoryEntries() throws {
    let entries = try (0...25).map { _ in
      try dataGen.createAndSaveExportResultHistoryEntry()
    }.sorted { $1.createdAt < $0.createdAt }

    let first10Expected = Array(entries[0..<10])
    let first10Res = try exporterDB.getExportResultHistoryEntries(limit: 10)
    #expect(
      first10Res == first10Expected,
      "\(Diff.getDiffAsString(first10Res, first10Expected) ?? "")",
    )

    let next10Expected = Array(entries[10..<20])
    let next10Res = try exporterDB.getExportResultHistoryEntries(limit: 10, offset: 10)
    #expect(
      next10Res == next10Expected,
      "\(Diff.getDiffAsString(next10Res, next10Expected) ?? "")",
    )
  }
}
