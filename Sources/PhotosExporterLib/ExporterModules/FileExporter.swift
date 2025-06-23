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

struct FileExporter {
  private let filesDirURL: URL
  private let exporterDB: ExporterDB
  private let photokit: PhotokitProtocol
  private let fileManager: ExporterFileManagerProtocol
  private let timeProvider: TimeProvider
  private let logger: ClassLogger

  public struct Result: Codable, Sendable, Equatable {
    let copied: Int
    let deleted: Int

    static func empty() -> Result {
      return Result(copied: 0, deleted: 0)
    }
  }

  struct ResultWithRemoved {
    let result: Result
    let fileMarkedForDeletion: Int

    static func empty() -> ResultWithRemoved {
      return ResultWithRemoved(
        result: Result.empty(),
        fileMarkedForDeletion: 0,
      )
    }
  }

  init(
    filesDirURL: URL,
    exporterDB: ExporterDB,
    photokit: PhotokitProtocol,
    fileManager: ExporterFileManagerProtocol,
    timeProvider: TimeProvider,
    logger: Logger,
  ) {
    self.filesDirURL = filesDirURL
    self.exporterDB = exporterDB
    self.photokit = photokit
    self.fileManager = fileManager
    self.timeProvider = timeProvider
    self.logger = ClassLogger(className: "FileCopier", logger: logger)
  }

  func run(isEnabled: Bool = false) async throws -> ResultWithRemoved {
    guard isEnabled else {
      logger.warning("File copying and deletion disabled - skipping")
      return ResultWithRemoved.empty()
    }
    let startDate = timeProvider.getDate()
    let copyRes = try await copy()
    let deletedCnt = try delete()

    logger.info("File copying and deletion complete in \(timeProvider.secondsPassedSince(startDate))s")
    return ResultWithRemoved(
      result: Result(
        copied: copyRes.result.copied,
        deleted: deletedCnt,
      ),
      fileMarkedForDeletion: copyRes.fileMarkedForDeletion
    )
  }

  private func copy() async throws -> ResultWithRemoved {
    logger.info("Getting Files to copy from local DB...")
    let filesWithAssetIdToCopy = try exporterDB.getFilesWithAssetIdsToCopy()

    guard filesWithAssetIdToCopy.count > 0 else {
      logger.info("No Files to copy")
      return ResultWithRemoved.empty()
    }

    logger.info("Copying files...")
    var copiedCnt = 0
    var markedForDeletionCnt = 0
    for toCopy in filesWithAssetIdToCopy {
      let destinationDirURL = filesDirURL.appending(path: toCopy.exportedFile.importedFileDir)
      let loggerMetadata: Logger.Metadata = ["id": "\(toCopy.exportedFile.id)"]

      if try fileManager.createDirectory(path: destinationDirURL.path(percentEncoded: false)) == .success {
        logger.trace("Created destination directory: \(destinationDirURL.path(percentEncoded: false))")
      }
      let destinationFileURL = destinationDirURL.appending(path: toCopy.exportedFile.id)

      let copyResult = try await photokit.copyResource(
        assetId: toCopy.assetIds.first!,
        resourceType: PhotokitAssetResourceType.fromExporterFileType(
          fileType: toCopy.exportedFile.fileType
        ),
        originalFileName: toCopy.exportedFile.originalFileName,
        destination: destinationFileURL
      )

      if copyResult == .exists {
        logger.warning("File was already copied but not updated in DB", loggerMetadata)
      }

      switch copyResult {
      case .removed:
        logger.trace("File removed in Photos - marking link as deleted in DB...", loggerMetadata)
        markedForDeletionCnt += 1
        _ = try exporterDB.markFileAsDeleted(id: toCopy.exportedFile.id, now: timeProvider.getDate())
      case .exists, .copied:
        logger.trace("File successfully copied - updating DB...", loggerMetadata)
        copiedCnt += 1
        _ = try exporterDB.markFileAsCopied(id: toCopy.exportedFile.id)
      }
      logger.trace("File updated in DB", loggerMetadata)
    }

    return ResultWithRemoved(
      result: Result(copied: copiedCnt, deleted: 0),
      fileMarkedForDeletion: markedForDeletionCnt,
    )
  }

  private func delete() throws -> Int {
    logger.debug("Checking for orphaned Files to delete...")
    let orphanedFiles = try exporterDB.getOrphanedFiles()

    guard !orphanedFiles.isEmpty else {
      logger.debug("No orphaned files to delete")
      return 0
    }
    logger.debug("Found \(orphanedFiles.count) orphaned Files to delete...")

    for file in orphanedFiles {
      let fileUrl = filesDirURL
        .appending(path: file.importedFileDir)
        .appending(path: file.id)

      let logMetadata: Logger.Metadata = [
        "id": "\(file.id)",
        "path": "\(fileUrl.absoluteString)",
      ]

      logger.debug("Deleting underlying file for Exported File...", logMetadata)
      _ = try fileManager.remove(url: fileUrl)

      logger.debug("Deleting Exported File from DB...", logMetadata)
      _ = try exporterDB.deleteFile(id: file.id)
    }

    return orphanedFiles.count
  }
}

extension FileExporter.Result: DiffableStruct {
  func getStructDiff(_ other: FileExporter.Result) -> StructDiff {
    return StructDiff()
      .add(diffProperty(other, \.copied))
      .add(diffProperty(other, \.deleted))
  }
}

extension FileExporter.ResultWithRemoved: DiffableStruct {
  func getStructDiff(_ other: FileExporter.ResultWithRemoved) -> StructDiff {
    return StructDiff()
      .add(diffProperty(other, \.result))
      .add(diffProperty(other, \.fileMarkedForDeletion))
  }
}
