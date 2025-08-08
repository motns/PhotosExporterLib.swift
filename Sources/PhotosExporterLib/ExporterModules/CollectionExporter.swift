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
    self.exporterDB = exporterDB
    self.photokit = photokit
    self.timeProvider = timeProvider
    self.logger = ClassLogger(className: "CollectionExporter", logger: logger)
  }

  func export(isEnabled: Bool = true) -> AsyncThrowingStream<
    TaskStatus<CollectionExporterResult>,
    Swift.Error
  > {
    return AsyncThrowingStream(
      bufferingPolicy: .bufferingNewest(1)
    ) { continuation in
      Task {
        guard isEnabled else {
          logger.warning("Collection export disabled - skipping")
          continuation.yield(.skipped)
          continuation.finish()
          return
        }

        guard !Task.isCancelled else {
          logger.warning("Collection Exporter Task cancelled")
          continuation.yield(.cancelled)
          continuation.finish()
          return
        }

        continuation.yield(.running(nil))

        do {
          logger.info("Exporting Folders and Albums to local DB...")
          let startDate = await timeProvider.getDate()

          let exportRes = try await exportFoldersAndAlbums()

          guard !Task.isCancelled else {
            logger.warning("Collection Exporter Task cancelled")
            continuation.yield(.cancelled)
            continuation.finish()
            return
          }

          let removeRes = try await removeDeletedFoldersAndAlbums()

          let runTime = await timeProvider.secondsPassedSince(startDate)
          logger.info("Folder and Album export complete in \(runTime)s")
          continuation.yield(.complete(
            exportRes.copy(
              folderDeleted: removeRes.folderDeleted,
              albumDeleted: removeRes.albumDeleted,
            )
          ))
          continuation.finish()
        } catch {
          continuation.yield(.failed("\(error)"))
          continuation.finish(throwing: Error.unexpectedError("\(error)"))
        }
      }
    }
  }

  private func exportFoldersAndAlbums() async throws -> CollectionExporterResult {
    let rootFolderResult = try await processPhotokitFolder(
      folder: try self.photokit.getRootFolder(),
      parentId: nil
    )

    var albumInsertedCnt = 0
    var albumUpdatedCnt = 0
    var albumUnchangedCnt = 0

    logger.debug("Processing shared Albums...")
    for sharedAlbum in try await self.photokit.getSharedAlbums() {
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
  ) async throws -> CollectionExporterResult {
    let loggerMetadata: Logger.Metadata = [
      "folder_id": "\(folder.id)"
    ]
    logger.debug("Processing Folder...", loggerMetadata)
    let startTime = await timeProvider.getDate()

    var folderInsertedCnt = 0
    var folderUpdatedCnt = 0
    var folderUnchangedCnt = 0
    var albumInsertedCnt = 0
    var albumUpdatedCnt = 0
    var albumUnchangedCnt = 0
    var runTime: Double = 0

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

    runTime = await timeProvider.secondsPassedSince(startTime)
    for subfolder in folder.subfolders {
      let subfolderRes = try await processPhotokitFolder(folder: subfolder, parentId: folder.id)
      folderInsertedCnt += subfolderRes.folderInserted
      folderUpdatedCnt += subfolderRes.folderUpdated
      folderUnchangedCnt += subfolderRes.folderUnchanged
      albumInsertedCnt += subfolderRes.albumInserted
      albumUpdatedCnt += subfolderRes.albumUpdated
      albumUnchangedCnt += subfolderRes.albumUnchanged
      runTime += subfolderRes.runTime
    }

    return CollectionExporterResult(
      folderInserted: folderInsertedCnt,
      folderUpdated: folderUpdatedCnt,
      folderUnchanged: folderUnchangedCnt,
      folderDeleted: 0,
      albumInserted: albumInsertedCnt,
      albumUpdated: albumUpdatedCnt,
      albumUnchanged: albumUnchangedCnt,
      albumDeleted: 0,
      runTime: runTime,
    )
  }

  private func removeDeletedFoldersAndAlbums() async throws -> CollectionExporterResult {
    logger.debug("Removing deleted Albums")

    let photosAlbumIds = try await getAllPhotosAlbumIds()
    let exportedAlbumIds = try self.exporterDB.getAlbumIdSet()
    let removedAlbumIds = exportedAlbumIds.subtracting(photosAlbumIds)

    if removedAlbumIds.isEmpty {
      logger.debug("No Album IDs to remove")
    } else {
      logger.debug("Found \(removedAlbumIds.count) Album IDs to remove")
    }

    for albumId in removedAlbumIds {
      logger.debug("Removing Album with ID...", [
        "id": "\(albumId)",
      ])
      _ = try self.exporterDB.deleteAlbum(albumId: albumId)
    }

    let photosFolderIds = try await getAllPhotosFolderIds()
    let exportedFolderIds = try self.exporterDB.getFolderIdSet()
    let removedFolderIds = exportedFolderIds.subtracting(photosFolderIds)

    if removedFolderIds.isEmpty {
      logger.debug("No Folder IDs to remove")
    } else {
      logger.debug("Found \(removedFolderIds.count) Folder IDs to remove")
    }

    for folderId in removedFolderIds {
      logger.debug("Removing Folder with ID...", [
        "id": "\(folderId)",
      ])
      _ = try self.exporterDB.deleteFolder(folderId: folderId)
    }

    return CollectionExporterResult.empty().copy(
      folderDeleted: removedFolderIds.count,
      albumDeleted: removedAlbumIds.count,
    )
  }

  private func getAllPhotosAlbumIds() async throws -> Set<String> {
    var albumIds = getFolderAlbumIds(
      folder: try await self.photokit.getRootFolder()
    )

    for sharedAlbum in try await self.photokit.getSharedAlbums() {
      albumIds.insert(sharedAlbum.id)
    }

    return albumIds
  }

  private func getFolderAlbumIds(folder: PhotokitFolder) -> Set<String> {
    var albumIds = Set(folder.albums.map { album in album.id })
    for subfolder in folder.subfolders {
      albumIds = albumIds.union(getFolderAlbumIds(folder: subfolder))
    }
    return albumIds
  }

  private func getAllPhotosFolderIds() async throws -> Set<String> {
    return getFolderSubfolderIds(
      folder: try await self.photokit.getRootFolder()
    )
  }

  private func getFolderSubfolderIds(folder: PhotokitFolder) -> Set<String> {
    var folderIds = Set([folder.id])
    for subfolder in folder.subfolders {
      folderIds = folderIds.union(getFolderSubfolderIds(folder: subfolder))
    }
    return folderIds
  }
}

public struct CollectionExporterResult: Codable, Sendable, Equatable, Timeable {
  public let folderInserted: Int
  public let folderUpdated: Int
  public let folderUnchanged: Int
  public let folderDeleted: Int
  public let albumInserted: Int
  public let albumUpdated: Int
  public let albumUnchanged: Int
  public let albumDeleted: Int
  public let runTime: Double

  public func copy(
    folderInserted: Int? = nil,
    folderUpdated: Int? = nil,
    folderUnchanged: Int? = nil,
    folderDeleted: Int? = nil,
    albumInserted: Int? = nil,
    albumUpdated: Int? = nil,
    albumUnchanged: Int? = nil,
    albumDeleted: Int? = nil,
    runTime: Double? = nil,
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
      runTime: runTime ?? self.runTime,
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
      runTime: 0,
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
      .add(diffProperty(other, \.runTime))
  }
}
