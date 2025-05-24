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

  @Test("Mark File as Copied")
  func markFileAsCopied() throws {
    let (_, file1, _) = try dataGen.insertLinkedFile()
    let (_, file2, _) = try dataGen.insertLinkedFile()

    try exporterDB.markFileAsCopied(id: file1.id)

    let copiedFile = try exporterDB.getFile(id: file1.id)
    #expect(copiedFile?.wasCopied == true)

    let nonCopiedFile = try exporterDB.getFile(id: file2.id)
    #expect(nonCopiedFile?.wasCopied == false)
  }

  @Test("Mark File as Deleted")
  func markFileAsDeleted() throws {
    let (asset, file, _) = try dataGen.insertLinkedFile()
    let now = TestHelpers.dateFromStr("2025-05-20 11:30:05")
    _ = try exporterDB.markFileAsDeleted(id: file.id, now: now)

    let updated = try exporterDB.getAssetFile(assetId: asset.id, fileId: file.id)
    #expect(updated?.isDeleted == true)
    #expect(updated?.deletedAt == now)
  }

  @Test("Get Files with AssetIdsToCopy")
  func getFilesWithAssetIdsToCopy() throws {
    let (asset1, file1, _) = try dataGen.insertLinkedFile()
    let (asset2, file2, _) = try dataGen.insertLinkedFile()

    let file3 = dataGen.createFile(asset: asset2).copy(
      wasCopied: true
    )
    _ = try exporterDB.upsertFile(file: file3)
    _ = try dataGen.insertAssetFile(asset: asset2, file: file3)

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
    let file1 = dataGen.createFile(asset: asset1, city: "London", country: "United Kingdom")
    _ = try self.exporterDB.upsertFile(file: file1)
    _ = try self.exporterDB.upsertAssetFile(assetFile: ExportedAssetFile(
      assetId: asset1.id,
      fileId: file1.id,
      isDeleted: false,
      deletedAt: nil,
    ))

    let asset2 = try dataGen.createExportedAsset()
    _ = try self.exporterDB.upsertAsset(asset: asset2)
    let file2 = dataGen.createFile(asset: asset2, city: "Madrid", country: "Spain")
    _ = try self.exporterDB.upsertFile(file: file2)
    _ = try self.exporterDB.upsertAssetFile(assetFile: ExportedAssetFile(
      assetId: asset2.id,
      fileId: file2.id,
      isDeleted: false,
      deletedAt: nil,
    ))

    let asset3 = try dataGen.createExportedAsset()
    _ = try self.exporterDB.upsertAsset(asset: asset3)
    let file3 = dataGen.createFile(asset: asset3, city: "Budapest", country: "Hungary")
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
    let asset = try dataGen.createExportedAsset()

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

    let newFile = dataGen.createFile(asset: asset, city: city, country: country)
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

    let newFile = dataGen.createFile(asset: asset, city: city, country: country)
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
    let file = dataGen.createFile(asset: asset)
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
    let file = dataGen.createFile(asset: asset)
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
}
