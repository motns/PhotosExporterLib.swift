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
import Logging

struct CollectionExporter {
  private let exporterDB: ExporterDB
  private let photokit: PhotokitProtocol
  private let timeProvider: TimeProvider
  private let logger: ClassLogger

  public struct Result: Codable, Sendable, Equatable {
    let folderInserted: Int
    let folderUpdated: Int
    let folderUnchanged: Int
    let albumInserted: Int
    let albumUpdated: Int
    let albumUnchanged: Int

    func copy(
      folderInserted: Int? = nil,
      folderUpdated: Int? = nil,
      folderUnchanged: Int? = nil,
      albumInserted: Int? = nil,
      albumUpdated: Int? = nil,
      albumUnchanged: Int? = nil,
    ) -> Result {
      return Result(
        folderInserted: folderInserted ?? self.folderInserted,
        folderUpdated: folderUpdated ?? self.folderUpdated,
        folderUnchanged: folderUnchanged ?? self.folderUnchanged,
        albumInserted: albumInserted ?? self.albumInserted,
        albumUpdated: albumUpdated ?? self.albumUpdated,
        albumUnchanged: albumUnchanged ?? self.albumUnchanged,
      )
    }

    static func empty() -> Result {
      return Result(
        folderInserted: 0,
        folderUpdated: 0,
        folderUnchanged: 0,
        albumInserted: 0,
        albumUpdated: 0,
        albumUnchanged: 0
      )
    }
  }

  init(
    exporterDB: ExporterDB,
    photokit: PhotokitProtocol,
    timeProvider: TimeProvider,
    logger: Logger,
  ) {
    self.exporterDB = exporterDB
    self.photokit = photokit
    self.timeProvider = timeProvider
    self.logger = ClassLogger(logger: logger, className: "CollectionExporter")
  }

  func export(isEnabled: Bool = true) throws -> Result {
    guard isEnabled else {
      logger.warning("Collection export disabled - skipping")
      return Result.empty()
    }
    logger.info("Exporting Folders and Albums to local DB...")
    let startDate = timeProvider.getDate()

    let rootFolderResult = try processPhotokitFolder(
      folder: try self.photokit.getRootFolder(),
      parentId: nil
    )

    var albumInsertedCnt = 0
    var albumUpdatedCnt = 0
    var albumUnchangedCnt = 0

    logger.debug("Processing shared Albums...")
    let sharedAlbums = try self.photokit.getSharedAlbums()
    for sharedAlbum in sharedAlbums {
      let albumUpsertRes = try self.exporterDB.upsertAlbum(
        album: ExportedAlbum.fromPhotokitAlbum(
          album: sharedAlbum,
          folderId: Photokit.RootFolderId,
        )
      )
      switch albumUpsertRes {
      case .insert: albumInsertedCnt += 1
      case .update: albumUpdatedCnt += 1
      case .nochange: albumUnchangedCnt += 1
      }
    }

    logger.info("Folder and Album export complete in \(timeProvider.secondsPassedSince(startDate))s")
    return rootFolderResult.copy(
      albumInserted: rootFolderResult.albumInserted + albumInsertedCnt,
      albumUpdated: rootFolderResult.albumUpdated + albumUpdatedCnt,
      albumUnchanged: rootFolderResult.albumUnchanged + albumUnchangedCnt,
    )
  }

  private func processPhotokitFolder(
    folder: PhotokitFolder,
    parentId: String?,
  ) throws -> Result {
    let loggerMetadata: Logger.Metadata = [
      "folder_id": "\(folder.id)"
    ]
    logger.debug("Processing Folder...", loggerMetadata)

    var folderInsertedCnt = 0
    var folderUpdatedCnt = 0
    var folderUnchangedCnt = 0
    var albumInsertedCnt = 0
    var albumUpdatedCnt = 0
    var albumUnchangedCnt = 0

    let exportedFolder = ExportedFolder.fromPhotokitFolder(
      folder: folder,
      parentId: parentId,
    )
    let folderUpsertRes = try self.exporterDB.upsertFolder(folder: exportedFolder)
    switch folderUpsertRes {
    case .insert: folderInsertedCnt += 1
    case .update: folderUpdatedCnt += 1
    case .nochange: folderUnchangedCnt += 1
    }

    for album in folder.albums {
      let exportedAlbum = try ExportedAlbum.fromPhotokitAlbum(
        album: album,
        folderId: folder.id,
      )
      let albumUpsertRes = try self.exporterDB.upsertAlbum(album: exportedAlbum)
      switch albumUpsertRes {
      case .insert: albumInsertedCnt += 1
      case .update: albumUpdatedCnt += 1
      case .nochange: albumUnchangedCnt += 1
      }
    }

    for subfolder in folder.subfolders {
      let subfolderRes = try processPhotokitFolder(folder: subfolder, parentId: folder.id)
      folderInsertedCnt += subfolderRes.folderInserted
      folderUpdatedCnt += subfolderRes.folderUpdated
      folderUnchangedCnt += subfolderRes.folderUnchanged
      albumInsertedCnt += subfolderRes.albumInserted
      albumUpdatedCnt += subfolderRes.albumUpdated
      albumUnchangedCnt += subfolderRes.albumUnchanged
    }

    return Result(
      folderInserted: folderInsertedCnt,
      folderUpdated: folderUpdatedCnt,
      folderUnchanged: folderUnchangedCnt,
      albumInserted: albumInsertedCnt,
      albumUpdated: albumUpdatedCnt,
      albumUnchanged: albumUnchangedCnt,
    )
  }
}

extension CollectionExporter.Result: DiffableStruct {
  func getStructDiff(_ other: CollectionExporter.Result) -> StructDiff {
    return StructDiff()
      .add(diffProperty(other, \.folderInserted))
      .add(diffProperty(other, \.folderUpdated))
      .add(diffProperty(other, \.folderUnchanged))
      .add(diffProperty(other, \.albumInserted))
      .add(diffProperty(other, \.albumUpdated))
      .add(diffProperty(other, \.albumUnchanged))
  }
}
