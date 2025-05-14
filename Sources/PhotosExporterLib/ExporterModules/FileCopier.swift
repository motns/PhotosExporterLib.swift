import Foundation
import Logging

struct FileCopier {
  private let filesDirURL: URL
  private let exporterDB: ExporterDB
  private let photokit: PhotokitProtocol
  private let timeProvider: TimeProvider
  private let logger: ClassLogger

  init(
    exportBaseDirURL: URL,
    exporterDB: ExporterDB,
    photokit: PhotokitProtocol,
    timeProvider: TimeProvider,
    logger: Logger,
  ) {
    self.filesDirURL = exportBaseDirURL.appending(path: "files")
    self.exporterDB = exporterDB
    self.photokit = photokit
    self.timeProvider = timeProvider
    self.logger = ClassLogger(logger: logger, className: "FileCopier")
  }

  // swiftlint:disable:next function_body_length
  func copy(isEnabled: Bool = false) async throws -> FileCopyResult {
    guard isEnabled else {
      logger.warning("File copying disabled - skipping")
      return FileCopyResult.empty()
    }
    let startDate = timeProvider.getDate()

    logger.info("Getting Files to copy from local DB...")
    let filesToCopy = try exporterDB.getFilesToCopy()

    guard filesToCopy.count > 0 else {
      logger.info("No Files to copy")
      return FileCopyResult(copied: 0, removed: 0)
    }

    logger.info("Copying files...")
    var copiedCount = 0
    var removedCount = 0
    for fileToCopy in filesToCopy {
      let destinationDirURL = filesDirURL.appending(path: fileToCopy.importedFileDir)
      let loggerMetadata: Logger.Metadata = [
        "asset_id": "\(fileToCopy.assetId)",
        "file_type": "\(fileToCopy.fileType)",
        "original_file_name": "\(fileToCopy.originalFileName)",
      ]

      if try FileHelper.createDirectory(path: destinationDirURL.path(percentEncoded: false)) {
        logger.trace("Created destination directory: \(destinationDirURL.path(percentEncoded: false))")
      }
      let destinationFileURL = destinationDirURL.appending(path: fileToCopy.importedFileName)

      let copyResult = try await photokit.copyResource(
        assetId: fileToCopy.assetId,
        fileType: fileToCopy.fileType,
        originalFileName: fileToCopy.originalFileName,
        destination: destinationFileURL
      )

      if copyResult == .exists {
        // These could be due to the Exporter previously crashing before updating the
        // record in the DB, but it's also possible that two or more assets are using
        // the exact same Resource - this happens when you create virtual copies in the
        // Photos library.
        logger.debug("File was already copied but not updated in DB", loggerMetadata)
      }

      switch copyResult {
      case .removed:
        logger.trace("File removed in Photos - marking as deleted in DB...", loggerMetadata)
        removedCount += 1
        let updatedFile = fileToCopy.copy(
          isDeleted: true,
          deletedAt: timeProvider.getDate()
        )
        _ = try exporterDB.upsertFile(file: updatedFile)
      case .exists, .copied:
        logger.trace("File successfully copied - updating DB...", loggerMetadata)
        copiedCount += 1
        let updatedFile = fileToCopy.copy(
          wasCopied: true
        )
        _ = try exporterDB.upsertFile(file: updatedFile)
      }
      logger.trace("File updated in DB", loggerMetadata)
    }

    logger.info("File copying complete in \(timeProvider.secondsPassedSince(startDate))s")
    return FileCopyResult(copied: copiedCount, removed: removedCount)
  }
}

public struct FileCopyResult: Sendable, Equatable {
  let copied: Int
  let removed: Int

  static func empty() -> FileCopyResult {
    return FileCopyResult(copied: 0, removed: 0)
  }
}
