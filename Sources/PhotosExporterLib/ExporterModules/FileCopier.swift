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

  func copy(isEnabled: Bool = false) async throws -> FileCopyResult {
    guard isEnabled else {
      logger.warning("File copying disabled - skipping")
      return FileCopyResult.empty()
    }
    let startDate = timeProvider.getDate()

    logger.info("Getting Files to copy from local DB...")
    let filesWithAssetIdToCopy = try exporterDB.getFilesWithAssetIdsToCopy()

    guard filesWithAssetIdToCopy.count > 0 else {
      logger.info("No Files to copy")
      return FileCopyResult(copied: 0, removed: 0)
    }

    logger.info("Copying files...")
    var copiedCount = 0
    var removedCount = 0
    for toCopy in filesWithAssetIdToCopy {
      let destinationDirURL = filesDirURL.appending(path: toCopy.exportedFile.importedFileDir)
      let loggerMetadata: Logger.Metadata = ["id": "\(toCopy.exportedFile.id)"]

      if try FileHelper.createDirectory(path: destinationDirURL.path(percentEncoded: false)) {
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
        removedCount += 1
        _ = try exporterDB.markFileAsDeleted(id: toCopy.exportedFile.id, now: timeProvider.getDate())
      case .exists, .copied:
        logger.trace("File successfully copied - updating DB...", loggerMetadata)
        copiedCount += 1
        _ = try exporterDB.markFileAsCopied(id: toCopy.exportedFile.id)
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
