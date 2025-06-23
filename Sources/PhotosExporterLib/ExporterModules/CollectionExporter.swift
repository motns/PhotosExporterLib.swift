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

struct CollectionExporter {
  public let runStatus: CollectionExporterStatus

  private let exporterDB: ExporterDB
  private let photokit: PhotokitProtocol
  private let timeProvider: TimeProvider
  private let logger: ClassLogger

  public enum Error: Swift.Error {
    case unexpectedError(String)
  }

  init(
    exporterDB: ExporterDB,
    photokit: PhotokitProtocol,
    timeProvider: TimeProvider,
    logger: Logger,
  ) {
    self.runStatus = CollectionExporterStatus()
    self.exporterDB = exporterDB
    self.photokit = photokit
    self.timeProvider = timeProvider
    self.logger = ClassLogger(className: "CollectionExporter", logger: logger)
  }

  func export(isEnabled: Bool = true) throws -> CollectionExporterResult {
    guard isEnabled else {
      logger.warning("Collection export disabled - skipping")
      runStatus.skipped()
      return CollectionExporterResult.empty()
    }

    do {
      logger.info("Exporting Folders and Albums to local DB...")
      let startDate = timeProvider.getDate()
      runStatus.start()

      let res = try exportFoldersAndAlbums()

      let runTime = timeProvider.secondsPassedSince(startDate)
      logger.info("Folder and Album export complete in \(runTime)s")
      runStatus.complete(runTime: runTime)
      return res
    } catch {
      runStatus.failed(error: "\(error)")
      throw Error.unexpectedError("\(error)")
    }
  }

  private func exportFoldersAndAlbums() throws -> CollectionExporterResult {
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

    return rootFolderResult.copy(
      albumInserted: rootFolderResult.albumInserted + albumInsertedCnt,
      albumUpdated: rootFolderResult.albumUpdated + albumUpdatedCnt,
      albumUnchanged: rootFolderResult.albumUnchanged + albumUnchangedCnt,
    )
  }

  // swiftlint:disable:next function_body_length
  private func processPhotokitFolder(
    folder: PhotokitFolder,
    parentId: String?,
  ) throws -> CollectionExporterResult {
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

    return CollectionExporterResult(
      folderInserted: folderInsertedCnt,
      folderUpdated: folderUpdatedCnt,
      folderUnchanged: folderUnchangedCnt,
      folderDeleted: 0, // TODO
      albumInserted: albumInsertedCnt,
      albumUpdated: albumUpdatedCnt,
      albumUnchanged: albumUnchangedCnt,
      albumDeleted: 0, // TODO
    )
  }
}

public struct CollectionExporterResult: Codable, Sendable, Equatable {
  public let folderInserted: Int
  public let folderUpdated: Int
  public let folderUnchanged: Int
  public let folderDeleted: Int
  public let albumInserted: Int
  public let albumUpdated: Int
  public let albumUnchanged: Int
  public let albumDeleted: Int

  public func copy(
    folderInserted: Int? = nil,
    folderUpdated: Int? = nil,
    folderUnchanged: Int? = nil,
    folderDeleted: Int? = nil,
    albumInserted: Int? = nil,
    albumUpdated: Int? = nil,
    albumUnchanged: Int? = nil,
    albumDeleted: Int? = nil,
  ) -> CollectionExporterResult {
    return CollectionExporterResult(
      folderInserted: folderInserted ?? self.folderInserted,
      folderUpdated: folderUpdated ?? self.folderUpdated,
      folderUnchanged: folderUnchanged ?? self.folderUnchanged,
      folderDeleted: folderDeleted ?? self.folderDeleted,
      albumInserted: albumInserted ?? self.albumInserted,
      albumUpdated: albumUpdated ?? self.albumUpdated,
      albumUnchanged: albumUnchanged ?? self.albumUnchanged,
      albumDeleted: albumDeleted ?? self.albumDeleted,
    )
  }

  public static func empty() -> CollectionExporterResult {
    return CollectionExporterResult(
      folderInserted: 0,
      folderUpdated: 0,
      folderUnchanged: 0,
      folderDeleted: 0,
      albumInserted: 0,
      albumUpdated: 0,
      albumUnchanged: 0,
      albumDeleted: 0,
    )
  }
}

extension CollectionExporterResult: DiffableStruct {
  func getStructDiff(_ other: CollectionExporterResult) -> StructDiff {
    return StructDiff()
      .add(diffProperty(other, \.folderInserted))
      .add(diffProperty(other, \.folderUpdated))
      .add(diffProperty(other, \.folderUnchanged))
      .add(diffProperty(other, \.folderDeleted))
      .add(diffProperty(other, \.albumInserted))
      .add(diffProperty(other, \.albumUpdated))
      .add(diffProperty(other, \.albumUnchanged))
      .add(diffProperty(other, \.albumDeleted))
  }
}

@Observable
public class CollectionExporterStatus: PhotosExporterLib.RunStatus {}
