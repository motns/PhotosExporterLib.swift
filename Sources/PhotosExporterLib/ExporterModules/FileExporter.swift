import Foundation
import Logging

struct FileExporter {
  private let filesDirURL: URL
  private let exporterDB: ExporterDB
  private let photokit: PhotokitProtocol
  private let fileManager: ExporterFileManagerProtocol
  private let timeProvider: TimeProvider
  private let logger: ClassLogger

  init(
    exportBaseDirURL: URL,
    exporterDB: ExporterDB,
    photokit: PhotokitProtocol,
    fileManager: ExporterFileManagerProtocol,
    timeProvider: TimeProvider,
    logger: Logger,
  ) {
    self.filesDirURL = exportBaseDirURL.appending(path: "files")
    self.exporterDB = exporterDB
    self.photokit = photokit
    self.fileManager = fileManager
    self.timeProvider = timeProvider
    self.logger = ClassLogger(logger: logger, className: "FileCopier")
  }

  func run(isEnabled: Bool = false) async throws -> FileExportResultWithRemoved {
    guard isEnabled else {
      logger.warning("File copying and deletion disabled - skipping")
      return FileExportResultWithRemoved.empty()
    }
    let startDate = timeProvider.getDate()
    let copyRes = try await copy()
    let deletedCnt = try delete()

    logger.info("File copying and deletion complete in \(timeProvider.secondsPassedSince(startDate))s")
    return FileExportResultWithRemoved(
      result: FileExportResult(
        copied: copyRes.result.copied,
        deleted: deletedCnt,
      ),
      fileMarkedForDeletion: copyRes.fileMarkedForDeletion
    )
  }

  private func copy() async throws -> FileExportResultWithRemoved {
    logger.info("Getting Files to copy from local DB...")
    let filesWithAssetIdToCopy = try exporterDB.getFilesWithAssetIdsToCopy()

    guard filesWithAssetIdToCopy.count > 0 else {
      logger.info("No Files to copy")
      return FileExportResultWithRemoved.empty()
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
      let destinationFileURL = destinationDirURL.appending(path: toCopy.exportedFile.importedFileName)

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

    return FileExportResultWithRemoved(
      result: FileExportResult(copied: copiedCnt, deleted: 0),
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
        .appending(path: file.importedFileName)

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

public struct FileExportResult: Sendable, Equatable {
  let copied: Int
  let deleted: Int

  static func empty() -> FileExportResult {
    return FileExportResult(copied: 0, deleted: 0)
  }
}

struct FileExportResultWithRemoved {
  let result: FileExportResult
  let fileMarkedForDeletion: Int

  static func empty() -> FileExportResultWithRemoved {
    return FileExportResultWithRemoved(
      result: FileExportResult.empty(),
      fileMarkedForDeletion: 0,
    )
  }
}
