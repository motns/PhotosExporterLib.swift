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
  let testDir: URL
  let exporterDB: ExporterDB
  let testTimeProvider: TestTimeProvider
  let dataGen: TestDataGenerator

  init() throws {
    self.testDir = try TestHelpers.createTestDir()
    let dbPath = testDir.appending(path: "testdb.sqlite")
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
    if FileManager.default.fileExists(atPath: testDir.path(percentEncoded: false)) {
      try? FileManager.default.removeItem(atPath: testDir.path(percentEncoded: false))
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

  @Test("Sum file sizes")
  func sumFileSizes() throws {
    let (_, file1, _) = try dataGen.createAndSaveLinkedFile()
    let (_, file2, _) = try dataGen.createAndSaveLinkedFile()
    let (_, file3, _) = try dataGen.createAndSaveLinkedFile()
    let expected = file1.fileSize + file2.fileSize + file3.fileSize
    let sum = try exporterDB.sumFileSizes()
    #expect(sum == expected)
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
    let asset4 = dataGen.createExportedAsset(isDeleted: true)
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

    let res = try exporterDB
      .getAlbumsInFolder(folderId: parentFolder.id)
      .sorted { $0.id < $1.id }
    let expected = [album1, album2].sorted { $0.id < $1.id }
    #expect(res == expected)
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
      "\(Diff.getDiff(res, expected).prettyDescription)"
    )
  }

  @Test("Get files with location")
  func getFilesWithLocation() throws {
    let asset1 = try dataGen.createAndSaveExportedAsset(
      createdAt: TestHelpers.dateFromStr("2025-03-01 12:00:00"),
    )
    let file1 = try dataGen.createAndSaveExportedFile(
      asset: asset1,
      country: "Spain",
      city: "Madrid",
    )
    _ = try dataGen.createAndSaveAssetFile(assetId: asset1.id, fileId: file1.id)

    let asset2 = try dataGen.createAndSaveExportedAsset(
      createdAt: TestHelpers.dateFromStr("2025-03-02 12:00:00"),
    )
    // Have two Assets point to the same file, to test the grouping in the query
    let asset3 = try dataGen.createAndSaveExportedAsset(
      createdAt: TestHelpers.dateFromStr("2025-03-03 12:00:00"),
    )
    let file2 = try dataGen.createAndSaveExportedFile(
      asset: asset2,
      country: "United Kingdom",
      city: "London",
    )
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
      "\(Diff.getDiff(filesWithLocation, expected).prettyDescription)",
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
      "\(Diff.getDiff(filesWithScore, expected).prettyDescription)",
    )
  }

  @Test("Get Files with AssetIdsToCopy")
  func getFilesWithAssetIdsToCopy() throws {
    let (asset1, file1, _) = try dataGen.createAndSaveLinkedFile()
    let (asset2, file2, _) = try dataGen.createAndSaveLinkedFile()

    let file3 = try dataGen.createExportedFile(asset: asset2).copy(
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

    let toCopy = try exporterDB
      .getFilesWithAssetIdsToCopy()
      .sorted { $0.exportedFile.id < $1.exportedFile.id }
    let expected = [fileWithAssetIds1, fileWithAssetIds2]
      .sorted { $0.exportedFile.id < $1.exportedFile.id }
    #expect(toCopy == expected)
  }

  @Test("Get Files for Album")
  // swiftlint:disable:next function_body_length
  func getFilesForAlbum() throws {
    let asset1 = dataGen.createExportedAsset()
    _ = try self.exporterDB.upsertAsset(asset: asset1)
    let file1 = try dataGen.createExportedFile(
      asset: asset1,
      country: "United Kingdom",
      city: "London",
    )
    _ = try self.exporterDB.upsertFile(file: file1)
    _ = try self.exporterDB.upsertAssetFile(assetFile: ExportedAssetFile(
      assetId: asset1.id,
      fileId: file1.id,
      isDeleted: false,
      deletedAt: nil,
    ))

    let asset2 = dataGen.createExportedAsset()
    _ = try self.exporterDB.upsertAsset(asset: asset2)
    let file2 = try dataGen.createExportedFile(
      asset: asset2,
      country: "Spain",
      city: "Madrid",
    )
    _ = try self.exporterDB.upsertFile(file: file2)
    _ = try self.exporterDB.upsertAssetFile(assetFile: ExportedAssetFile(
      assetId: asset2.id,
      fileId: file2.id,
      isDeleted: false,
      deletedAt: nil,
    ))

    let asset3 = dataGen.createExportedAsset()
    _ = try self.exporterDB.upsertAsset(asset: asset3)
    let file3 = try dataGen.createExportedFile(
      asset: asset3,
      country: "Hungary",
      city: "Budapest",
    )
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

    let filesForAlbum = try self.exporterDB
      .getFilesForAlbum(albumId: newAlbum.id)
      .sorted { $0.id < $1.id }
    let expected = [file1, file2, file3].sorted { $0.id < $1.id }
    #expect(filesForAlbum == expected)
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

    let res = try exporterDB
      .getFoldersWithParent(parentId: parentFolder.id)
      .sorted { $0.id < $1.id }
    let expected = [childFolder1, childFolder2].sorted { $0.id < $1.id }
    #expect(res == expected)
  }

  // - MARK: Updates

  @Test("Upsert Asset - New")
  func upsertAssetNew() throws {
    let newAsset = dataGen.createExportedAsset()
    let insertRes = try self.exporterDB.upsertAsset(asset: newAsset)
    #expect(insertRes == ExporterDB.UpsertResult.insert)

    let insertedAsset = try? exporterDB.getAsset(id: newAsset.id)
    #expect(insertedAsset == newAsset)
  }

  @Test("Upsert Asset - Update")
  func upsertAssetUpdate() throws {
    let asset = dataGen.createExportedAsset(
      isFavourite: false
    )

    let insertRes = try self.exporterDB.upsertAsset(asset: asset)
    #expect(insertRes == ExporterDB.UpsertResult.insert)

    let updated = asset.copy(isFavourite: true)
    let updateRes = try self.exporterDB.upsertAsset(asset: updated)
    #expect(updateRes == ExporterDB.UpsertResult.update)

    let updatedAsset = try? exporterDB.getAsset(id: asset.id)
    let updatedToCheck = updated.copy(updatedAt: updatedAsset?.updatedAt)
    #expect(updatedAsset == updatedToCheck)
  }

  @Test("Upsert File - New")
  func upsertFileNew() throws {
    let asset = dataGen.createExportedAsset()
    _ = try self.exporterDB.upsertAsset(asset: asset)

    let newFile = try dataGen.createExportedFile(
      asset: asset,
      country: "United Kingdom",
      city: "London",
    )
    let insertRes = try self.exporterDB.upsertFile(file: newFile)
    #expect(insertRes == ExporterDB.UpsertResult.insert)

    let duplicateRes = try self.exporterDB.upsertFile(file: newFile)
    #expect(duplicateRes == ExporterDB.UpsertResult.nochange)

    let insertedFile = try? exporterDB.getFile(id: newFile.id)
    #expect(insertedFile == newFile)
  }

  @Test("Upsert File - Update")
  func upsertFileUpdate() throws {
    let asset = dataGen.createExportedAsset()
    _ = try self.exporterDB.upsertAsset(asset: asset)

    let newFile = try dataGen.createExportedFile(
      asset: asset,
      country: "United Kingdom",
      city: "London",
    )
    let insertRes = try self.exporterDB.upsertFile(file: newFile)
    #expect(insertRes == ExporterDB.UpsertResult.insert)

    let updatedFile = newFile.copy(wasCopied: true)
    _ = try exporterDB.upsertFile(file: updatedFile)

    let updatedToCheck = try? exporterDB.getFile(id: newFile.id)
    #expect(updatedToCheck == updatedFile)
  }

  @Test("Upsert File - Changing location")
  func upsertFileChangingLocation() throws {
    let asset = try dataGen.createAndSaveExportedAsset()
    let newFile = try dataGen.createAndSaveExportedFile(
      asset: asset,
      country: nil,
      city: nil,
      wasCopied: true,
    )

    let fileWithLocation = newFile.copy(
      geoLat: Decimal(string: "40.423325"),
      geoLong: Decimal(string: "-3.694627"),
      countryId: try exporterDB.getLookupTableIdByName(table: .country, name: "Spain"),
      cityId: try exporterDB.getLookupTableIdByName(table: .city, name: "Madrid"),
      importedFileDir: "2025/2025-03_spain_madrid",
      wasCopied: false, // Location change resets copied flag
    )
    _ = try exporterDB.upsertFile(file: fileWithLocation)
    let fileWithLocationInDB = try exporterDB.getFile(id: newFile.id)
    #expect(
      fileWithLocationInDB == fileWithLocation,
      "\(fileWithLocationInDB.diff(fileWithLocation).prettyDescription)"
    )

    let fileRemovedLocation = fileWithLocation.copy(
      geoLat: nil,
      geoLong: nil,
      countryId: .some(nil),
      cityId: .some(nil),
      importedFileDir: "2025/2025-03",
    )
    _ = try exporterDB.upsertFile(file: fileRemovedLocation)
    let fileRemovedLocationInDB = try exporterDB.getFile(id: newFile.id)
    #expect(
      fileRemovedLocationInDB == fileWithLocation, // Should be unchanged
      "\(fileRemovedLocationInDB.diff(fileWithLocation).prettyDescription)",
    )

    let fileChangedLocation = fileWithLocation.copy(
      geoLat: Decimal(string: "47.507047"),
      geoLong: Decimal(string: "19.047039"),
      countryId: try exporterDB.getLookupTableIdByName(table: .country, name: "Hungary"),
      cityId: try exporterDB.getLookupTableIdByName(table: .city, name: "Budapest"),
      importedFileDir: "2025/2025-03_hungary_budapest",
    )
    _ = try exporterDB.upsertFile(file: fileChangedLocation)
    let fileChangedLocationInDB = try exporterDB.getFile(id: newFile.id)
    #expect(
      fileChangedLocationInDB == fileChangedLocation,
      "\(fileChangedLocationInDB.diff(fileChangedLocation).prettyDescription)",
    )
  }

  @Test("Upsert File - Protect wasCopied")
  func upsertFileProtectWasCopied() throws {
    let asset = try dataGen.createAndSaveExportedAsset()
    let newFile = try dataGen.createAndSaveExportedFile(
      asset: asset,
      country: nil,
      city: nil,
      wasCopied: false,
    )

    // Allow going from `false` to `true`
    let copiedFile = newFile.copy(
      wasCopied: true
    )
    _ = try exporterDB.upsertFile(file: copiedFile)
    let copiedFileInDB = try exporterDB.getFile(id: newFile.id)
    #expect(
      copiedFileInDB == copiedFile,
      "\(copiedFileInDB.diff(copiedFile).prettyDescription)"
    )

    // Don't allow going from `true` to `false`
    let uncopiedFile = newFile.copy(
      wasCopied: false
    )
    _ = try exporterDB.upsertFile(file: uncopiedFile)
    let uncopiedFileInDB = try exporterDB.getFile(id: newFile.id)
    #expect(
      uncopiedFileInDB == copiedFile,
      "\(uncopiedFileInDB.diff(copiedFile).prettyDescription)"
    )
  }

  @Test("Upsert Asset File - New")
  func upsertAssetFileNew() throws {
    let asset = dataGen.createExportedAsset()
    let file = try dataGen.createExportedFile(asset: asset)
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
    let asset = dataGen.createExportedAsset()
    let file = try dataGen.createExportedFile(asset: asset)
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
    #expect(res == ExporterDB.UpsertResult.insert)

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
    #expect(insertRes == ExporterDB.UpsertResult.insert)

    let updatedFolder = newFolder.copy(name: "New Name")
    let updatedRes = try self.exporterDB.upsertFolder(folder: updatedFolder)
    #expect(updatedRes == ExporterDB.UpsertResult.update)

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
    #expect(insertRes == ExporterDB.UpsertResult.insert)

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
    #expect(insertRes == ExporterDB.UpsertResult.insert)

    let updatedAlbum = newAlbum.copy(
      name: "Best Photos"
    )
    let updateRes = try self.exporterDB.upsertAlbum(album: updatedAlbum)
    #expect(updateRes == ExporterDB.UpsertResult.update)
    let nochangeRes = try self.exporterDB.upsertAlbum(album: updatedAlbum)
    #expect(nochangeRes == ExporterDB.UpsertResult.nochange)

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
      "\(Diff.getDiff(assets, expected).prettyDescription)",
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
      "\(Diff.getDiff(assetFiles, expected).prettyDescription)",
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
  func insertExportResultHistoryEntry() async throws {
    let now = await testTimeProvider.getDate()
    let entry = dataGen.createExportResultHistoryEntry(now: now)

    try exporterDB.insertExportResultHistoryEntry(entry: entry)
    let entryInDB = try exporterDB.getExportResultHistoryEntry(id: entry.id)
    #expect(
      entryInDB == entry,
      "\(entryInDB?.diff(entry).prettyDescription ?? "empty")"
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
      "\(latestEntryInDB?.diff(latestEntry).prettyDescription ?? "empty")"
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
      "\(Diff.getDiff(first10Res, first10Expected).prettyDescription)",
    )

    let next10Expected = Array(entries[10..<20])
    let next10Res = try exporterDB.getExportResultHistoryEntries(limit: 10, offset: 10)
    #expect(
      next10Res == next10Expected,
      "\(Diff.getDiff(next10Res, next10Expected).prettyDescription)",
    )
  }
}
