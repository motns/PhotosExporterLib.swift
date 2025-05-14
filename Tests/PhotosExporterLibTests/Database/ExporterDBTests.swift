import Foundation
import Logging
import Testing
@testable import PhotosExporterLib

@Suite("Exporter DB tests")
// swiftlint:disable:next type_body_length
final class ExporterDBTests {
  let testDir: String
  let exporterDB: ExporterDB
  let testTimeProvider: TestTimeProvider

  init() async throws {
    self.testDir = try TestHelpers.createTestDir()
    let dbPath = testDir + "/testdb.sqlite"
    var logger = Logger(label: "io.motns.testing")
    logger.logLevel = .critical
    self.testTimeProvider = TestTimeProvider()
    self.exporterDB = try ExporterDB(
      exportDBPath: dbPath,
      logger: logger,
    )
  }

  deinit {
    if FileManager.default.fileExists(atPath: testDir) {
      try? FileManager.default.removeItem(atPath: testDir)
    }
  }

  func createAsset(cityId: Int64?, countryId: Int64?) -> ExportedAsset {
    return ExportedAsset(
      id: UUID().uuidString,
      assetType: AssetType.image,
      assetLibrary: .personalLibrary,
      createdAt: TestHelpers.dateFromStr("2025-03-15 11:30:05"),
      updatedAt: nil,
      importedAt: TestHelpers.dateFromStr("2025-03-20 11:30:05")!,
      isFavourite: false,
      geoLat: 51.507861,
      geoLong: -0.160310,
      cityId: cityId,
      countryId: countryId,
      isDeleted: false,
      deletedAt: nil
    )
  }

  func createAsset(city: String, country: String) throws -> ExportedAsset {
    let cityId = try self.exporterDB.getLookupTableIdByName(
      table: .city, name: city
    )
    let countryId = try self.exporterDB.getLookupTableIdByName(
      table: .country, name: country
    )
    return createAsset(cityId: cityId, countryId: countryId)
  }

  func createAsset() throws -> ExportedAsset {
    return try createAsset(city: "London", country: "United Kingdom")
  }

  func createFile(asset: ExportedAsset, city: String?, country: String?) -> ExportedFile {
    return ExportedFile(
      assetId: asset.id,
      fileType: FileType.originalImage,
      originalFileName: "IMG004.jpg",
      importedAt: TestHelpers.dateFromStr("2025-03-15 11:30:05")!,
      importedFileDir: FileHelper.pathForDateAndLocation(
        dateOpt: asset.createdAt,
        countryOpt: country,
        cityOpt: city
      ),
      importedFileName: FileHelper.filenameWithDateAndEdited(
        originalFileName: "IMG004.jpg",
        dateOpt: asset.createdAt,
        isEdited: FileType.originalImage.isEdited()
      ),
      wasCopied: false,
      isDeleted: false,
      deletedAt: nil
    )
  }

  @Test("Get Folders with Parent")
  func getFoldersWithParent() async throws {
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
  func getAlbumsInFolder() async throws {
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

  @Test("Get Files for Album")
  func getFilesForAlbum() async throws {
    let asset1 = try createAsset()
    _ = try self.exporterDB.upsertAsset(asset: asset1)
    let file1 = createFile(asset: asset1, city: "London", country: "United Kingdom")
    _ = try self.exporterDB.upsertFile(file: file1)

    let asset2 = try createAsset()
    _ = try self.exporterDB.upsertAsset(asset: asset2)
    let file2 = createFile(asset: asset2, city: "Madrid", country: "Spain")
    _ = try self.exporterDB.upsertFile(file: file2)

    let asset3 = try createAsset()
    _ = try self.exporterDB.upsertAsset(asset: asset3)
    let file3 = createFile(asset: asset3, city: "Budapest", country: "Hungary")
    _ = try self.exporterDB.upsertFile(file: file3)

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
  func upsertAssetNew() async throws {
    let newAsset = try createAsset()
    let insertRes = try self.exporterDB.upsertAsset(asset: newAsset)
    #expect(insertRes == UpsertResult.insert)

    let insertedAsset = try? exporterDB.getAsset(id: newAsset.id)
    #expect(insertedAsset == newAsset)
  }

  @Test("Upsert Asset - Update")
  func upsertAssetUpdate() async throws {
    let asset = try createAsset()

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
  func upsertFileNew() async throws {
    let city = "London"
    let country = "United Kingdom"
    let asset = try createAsset(city: city, country: country)
    _ = try self.exporterDB.upsertAsset(asset: asset)

    let newFile = createFile(asset: asset, city: city, country: country)
    let insertRes = try self.exporterDB.upsertFile(file: newFile)
    #expect(insertRes == UpsertResult.insert)

    let duplicateRes = try self.exporterDB.upsertFile(file: newFile)
    #expect(duplicateRes == UpsertResult.nochange)

    let insertedFile = try? exporterDB.getFile(
      assetId: newFile.assetId,
      fileType: newFile.fileType,
      originalFileName: newFile.originalFileName,
    )
    #expect(insertedFile == newFile)
  }

  @Test("Upsert File - Update")
  func upsertFileUpdate() async throws {
    let city = "London"
    let country = "United Kingdom"
    let asset = try createAsset(city: city, country: country)
    _ = try self.exporterDB.upsertAsset(asset: asset)

    let newFile = createFile(asset: asset, city: city, country: country)
    let insertRes = try self.exporterDB.upsertFile(file: newFile)
    #expect(insertRes == UpsertResult.insert)

    let updatedFile = newFile.copy(wasCopied: true)
    _ = try exporterDB.upsertFile(file: updatedFile)

    let updatedToCheck = try? exporterDB.getFile(
      assetId: newFile.assetId,
      fileType: newFile.fileType,
      originalFileName: newFile.originalFileName,
    )
    #expect(updatedToCheck == updatedFile)
  }

  @Test("Upsert Folder - New")
  func upsertFolderNew() async throws {
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
  func upsertFolderUpdate() async throws {
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
  func upsertAlbumNew() async throws {
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
  func upsertAlbumUpdate() async throws {
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
