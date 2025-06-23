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
  public let runStatus: FileExporterStatus

  private let filesDirURL: URL
  private let exporterDB: ExporterDB
  private let photokit: PhotokitProtocol
  private let fileManager: ExporterFileManagerProtocol
  private let timeProvider: TimeProvider
  private let logger: ClassLogger

  public enum Error: Swift.Error {
    case unexpectedError(String)
  }

  init(
    filesDirURL: URL,
    exporterDB: ExporterDB,
    photokit: PhotokitProtocol,
    fileManager: ExporterFileManagerProtocol,
    timeProvider: TimeProvider,
    logger: Logger,
  ) {
    self.runStatus = FileExporterStatus()
    self.filesDirURL = filesDirURL
    self.exporterDB = exporterDB
    self.photokit = photokit
    self.fileManager = fileManager
    self.timeProvider = timeProvider
    self.logger = ClassLogger(className: "FileCopier", logger: logger)
  }

  func run(isEnabled: Bool = false) async throws -> FileExporterResultWithRemoved {
    guard isEnabled else {
      logger.warning("File copying and deletion disabled - skipping")
      runStatus.skipped()
      return FileExporterResultWithRemoved.empty()
    }
    do {
      runStatus.start()
      let startDate = timeProvider.getDate()
      let copyRes = try await copy()
      let deletedCnt = try delete()

      let runTime = timeProvider.secondsPassedSince(startDate)
      logger.info("File copying and deletion complete in \(runTime)s")
      runStatus.complete(runTime: runTime)
      return FileExporterResultWithRemoved(
        result: FileExporterResult(
          copied: copyRes.result.copied,
          deleted: deletedCnt,
        ),
        fileMarkedForDeletion: copyRes.fileMarkedForDeletion
      )
    } catch {
      runStatus.failed(error: "\(error)")
      throw Error.unexpectedError("\(error)")
    }
  }

  // swiftlint:disable:next function_body_length
  private func copy() async throws -> FileExporterResultWithRemoved {
    do {
      logger.info("Getting Files to copy from local DB...")
      runStatus.copyStatus.start()
      let startTime = timeProvider.getDate()
      let filesWithAssetIdToCopy = try exporterDB.getFilesWithAssetIdsToCopy()

      guard filesWithAssetIdToCopy.count > 0 else {
        logger.info("No Files to copy")
        runStatus.copyStatus.complete(runTime: timeProvider.secondsPassedSince(startTime))
        return FileExporterResultWithRemoved.empty()
      }

      logger.info("Copying files...")
      runStatus.copyStatus.startProgress(toProcess: filesWithAssetIdToCopy.count)
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

        runStatus.copyStatus.processed()
      }

      runStatus.copyStatus.complete(runTime: timeProvider.secondsPassedSince(startTime))
      return FileExporterResultWithRemoved(
        result: FileExporterResult(copied: copiedCnt, deleted: 0),
        fileMarkedForDeletion: markedForDeletionCnt,
      )
    } catch {
      runStatus.copyStatus.failed(error: "\(error)")
      throw error
    }
  }

  private func delete() throws -> Int {
    do {
      logger.debug("Checking for orphaned Files to delete...")
      let startTime = timeProvider.getDate()
      runStatus.deleteStatus.start()
      let orphanedFiles = try exporterDB.getOrphanedFiles()

      guard !orphanedFiles.isEmpty else {
        logger.debug("No orphaned files to delete")
        runStatus.deleteStatus.complete(runTime: timeProvider.secondsPassedSince(startTime))
        return 0
      }
      logger.debug("Found \(orphanedFiles.count) orphaned Files to delete...")
      runStatus.deleteStatus.startProgress(toProcess: orphanedFiles.count)

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
        runStatus.deleteStatus.processed()
      }

      runStatus.deleteStatus.complete(runTime: timeProvider.secondsPassedSince(startTime))
      return orphanedFiles.count
    } catch {
      runStatus.deleteStatus.failed(error: "\(error)")
      throw error
    }
  }
}

public struct FileExporterResult: Codable, Sendable, Equatable {
  let copied: Int
  let deleted: Int

  static func empty() -> FileExporterResult {
    return FileExporterResult(copied: 0, deleted: 0)
  }
}

public struct FileExporterResultWithRemoved {
  let result: FileExporterResult
  let fileMarkedForDeletion: Int

  static func empty() -> FileExporterResultWithRemoved {
    return FileExporterResultWithRemoved(
      result: FileExporterResult.empty(),
      fileMarkedForDeletion: 0,
    )
  }
}

extension FileExporterResult: DiffableStruct {
  func getStructDiff(_ other: FileExporterResult) -> StructDiff {
    return StructDiff()
      .add(diffProperty(other, \.copied))
      .add(diffProperty(other, \.deleted))
  }
}

extension FileExporterResultWithRemoved: DiffableStruct {
  func getStructDiff(_ other: FileExporterResultWithRemoved) -> StructDiff {
    return StructDiff()
      .add(diffProperty(other, \.result))
      .add(diffProperty(other, \.fileMarkedForDeletion))
  }
}

@Observable
public class FileExporterStatus: PhotosExporterLib.RunStatus {
  public let copyStatus: PhotosExporterLib.RunStatusWithProgress
  public let deleteStatus: PhotosExporterLib.RunStatusWithProgress

  public init(
    copyStatus: PhotosExporterLib.RunStatusWithProgress? = nil,
    deleteStatus: PhotosExporterLib.RunStatusWithProgress? = nil,
  ) {
    self.copyStatus = copyStatus ?? PhotosExporterLib.RunStatusWithProgress()
    self.deleteStatus = deleteStatus ?? PhotosExporterLib.RunStatusWithProgress()
  }
}
