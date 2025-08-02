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

extension Logger: Sendable {}

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
struct FileExporter: Sendable {
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
    self.filesDirURL = filesDirURL
    self.exporterDB = exporterDB
    self.photokit = photokit
    self.fileManager = fileManager
    self.timeProvider = timeProvider
    self.logger = ClassLogger(className: "FileExporter", logger: logger)
  }

  // swiftlint:disable:next function_body_length cyclomatic_complexity
  func run(isEnabled: Bool = false) -> AsyncThrowingStream<
    FileExporterStatus,
    Swift.Error
  > {
    return AsyncThrowingStream(
      bufferingPolicy: .bufferingNewest(10)
    ) { continuation in
      Task {
        var status = FileExporterStatus.notStarted()

        guard isEnabled else {
          logger.warning("File copying and deletion disabled - skipping")
          status = status.withMainStatus(.skipped)
          continuation.yield(status)
          continuation.finish()
          return
        }

        status = status.withMainStatus(.running(nil))
        continuation.yield(status)
        let startDate = await timeProvider.getDate()

        var copyRes: CopyFileResult = CopyFileResult.empty()
        do {
          for try await copyStatus in copy() {
            switch copyStatus {
            case .notStarted, .skipped, .cancelled: break
            case .running:
              status = status.withCopyStatus(copyStatus)
              continuation.yield(status)
            case .failed(let error):
              status = status.withMainStatus(.failed(error)).withCopyStatus(copyStatus)
              continuation.yield(status)
              continuation.finish(throwing: Error.unexpectedError("\(error)"))
              return
            case .complete(let result):
              copyRes = result
              status = status.withCopyStatus(copyStatus)
              continuation.yield(status)
            }
          }
        } catch {
          status = status
              .withMainStatus(.failed("\(error)"))
              .withCopyStatus(.failed("\(error)"))
          continuation.yield(status)
          continuation.finish(throwing: Error.unexpectedError("\(error)"))
        }

        do {
          var deleteRes: DeleteFileResult = DeleteFileResult.empty()
          for try await deleteStatus in delete() {
            switch deleteStatus {
            case .notStarted, .skipped, .cancelled: break
            case .running:
              status = status.withDeleteStatus(deleteStatus)
              continuation.yield(status)
            case .failed(let error):
              status = status.withMainStatus(.failed(error)).withDeleteStatus(deleteStatus)
              continuation.yield(status)
              continuation.finish(throwing: Error.unexpectedError("\(error)"))
              return
            case .complete(let result):
              deleteRes = result
              status = status.withDeleteStatus(deleteStatus)
              continuation.yield(status)
            }
          }

          let runTime = await timeProvider.secondsPassedSince(startDate)
          logger.info("File copying and deletion complete in \(runTime)s")
          status = status.withMainStatus(
            .complete(
              FileExporterResultWithRemoved(
                result: FileExporterResult(
                  copied: copyRes.copied,
                  deleted: deleteRes.deleted,
                  runTime: runTime,
                ),
                fileMarkedForDeletion: copyRes.markedForDeletion,
                runTime: runTime,
              )
            )
          )
          continuation.yield(status)
          continuation.finish()
        } catch {
          status = status
            .withMainStatus(.failed("\(error)"))
            .withDeleteStatus(.failed("\(error)"))
          continuation.yield(status)
          continuation.finish(throwing: Error.unexpectedError("\(error)"))
        }
      }
    }
  }

  // swiftlint:disable:next function_body_length
  private func copy() -> AsyncThrowingStream<
    TaskStatus<CopyFileResult>,
    Swift.Error
  > {
    AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
      Task {
        var status: TaskStatus<CopyFileResult> = .notStarted

        do {
          guard !Task.isCancelled else {
            logger.info("File Copy Task cancelled")
            continuation.yield(.cancelled)
            continuation.finish()
            return
          }

          logger.info("Getting Files to copy from local DB...")
          status = .running(nil)
          continuation.yield(status)
          let startTime = await timeProvider.getDate()
          let filesWithAssetIdToCopy = try exporterDB.getFilesWithAssetIdsToCopy()

          guard filesWithAssetIdToCopy.count > 0 else {
            logger.info("No Files to copy")
            continuation.yield(TaskStatus<CopyFileResult>.complete(
              CopyFileResult(
                copied: 0,
                markedForDeletion: 0,
                runTime: await timeProvider.secondsPassedSince(startTime),
              )
            ))
            continuation.finish()
            return
          }

          logger.info("Copying files...")
          var progress = TaskProgress(toProcess: filesWithAssetIdToCopy.count)
          status = .running(progress)
          continuation.yield(status)
          var copiedCnt = 0
          var markedForDeletionCnt = 0
          for toCopy in filesWithAssetIdToCopy {
            guard !Task.isCancelled else {
              logger.info("File Copy Task cancelled")
              continuation.yield(.cancelled)
              continuation.finish()
              return
            }

            let destinationDirURL = filesDirURL.appending(path: toCopy.exportedFile.importedFileDir)
            let loggerMetadata: Logger.Metadata = ["id": "\(toCopy.exportedFile.id)"]

            if try await fileManager.createDirectory(path: destinationDirURL.path(percentEncoded: false)) == .success {
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
              _ = try exporterDB.markFileAsDeleted(id: toCopy.exportedFile.id, now: await timeProvider.getDate())
            case .exists, .copied:
              logger.trace("File successfully copied - updating DB...", loggerMetadata)
              copiedCnt += 1
              _ = try exporterDB.markFileAsCopied(id: toCopy.exportedFile.id)
            }
            logger.trace("File updated in DB", loggerMetadata)

            progress = progress.processed()
            status = .running(progress)
            continuation.yield(status)
          }

          continuation.yield(
            TaskStatus<CopyFileResult>.complete(
              CopyFileResult(
                copied: copiedCnt,
                markedForDeletion: markedForDeletionCnt,
                runTime: await timeProvider.secondsPassedSince(startTime),
              )
            )
          )
          continuation.finish()
        } catch {
          continuation.yield(
            TaskStatus<CopyFileResult>.failed("\(error)")
          )
          continuation.finish(throwing: error)
        }
      }
    }
  }

  // swiftlint:disable:next function_body_length
  private func delete() -> AsyncThrowingStream<
    TaskStatus<DeleteFileResult>,
    Swift.Error
  > {
    return AsyncThrowingStream { continuation in
      Task {
        var status: TaskStatus<DeleteFileResult> = .notStarted

        do {
          guard !Task.isCancelled else {
            logger.info("File Delete Task cancelled")
            continuation.yield(.cancelled)
            continuation.finish()
            return
          }

          logger.debug("Checking for orphaned Files to delete...")
          let startTime = await timeProvider.getDate()
          status = .running(nil)
          continuation.yield(status)
          let orphanedFiles = try exporterDB.getOrphanedFiles()

          guard !orphanedFiles.isEmpty else {
            logger.debug("No orphaned files to delete")
            continuation.yield(TaskStatus<DeleteFileResult>.complete(
              DeleteFileResult(
                deleted: 0,
                runTime: await timeProvider.secondsPassedSince(startTime),
              )
            ))
            continuation.finish()
            return
          }
          logger.debug("Found \(orphanedFiles.count) orphaned Files to delete...")
          var progress = TaskProgress(toProcess: orphanedFiles.count)
          status = .running(progress)
          continuation.yield(status)

          for file in orphanedFiles {
            guard !Task.isCancelled else {
              logger.info("File Delete Task cancelled")
              continuation.yield(.cancelled)
              continuation.finish()
              return
            }

            let fileUrl = filesDirURL
              .appending(path: file.importedFileDir)
              .appending(path: file.id)

            let logMetadata: Logger.Metadata = [
              "id": "\(file.id)",
              "path": "\(fileUrl.absoluteString)",
            ]

            logger.debug("Deleting underlying file for Exported File...", logMetadata)
            _ = try await fileManager.remove(url: fileUrl)

            logger.debug("Deleting Exported File from DB...", logMetadata)
            _ = try exporterDB.deleteFile(id: file.id)
            progress = progress.processed()
            status = .running(progress)
            continuation.yield(status)
          }

          continuation.yield(
            TaskStatus<DeleteFileResult>.complete(
              DeleteFileResult(
                deleted: orphanedFiles.count,
                runTime: await timeProvider.secondsPassedSince(startTime),
              )
            )
          )
          continuation.finish()
        } catch {
          continuation.yield(
            TaskStatus<DeleteFileResult>.failed("\(error)")
          )
          continuation.finish(throwing: error)
        }
      }
    }
  }
}

public struct FileExporterResult: Codable, Sendable, Equatable, Timeable {
  public let copied: Int
  public let deleted: Int
  public let runTime: Double

  static func empty() -> FileExporterResult {
    return FileExporterResult(
      copied: 0,
      deleted: 0,
      runTime: 0,
    )
  }
}

public struct FileExporterResultWithRemoved: Sendable, Timeable {
  public let result: FileExporterResult
  public let fileMarkedForDeletion: Int
  public let runTime: Double

  static func empty() -> FileExporterResultWithRemoved {
    return FileExporterResultWithRemoved(
      result: FileExporterResult.empty(),
      fileMarkedForDeletion: 0,
      runTime: 0,
    )
  }
}

extension FileExporterResult: DiffableStruct {
  func getStructDiff(_ other: FileExporterResult) -> StructDiff {
    return StructDiff()
      .add(diffProperty(other, \.copied))
      .add(diffProperty(other, \.deleted))
      .add(diffProperty(other, \.runTime))
  }
}

extension FileExporterResultWithRemoved: DiffableStruct {
  func getStructDiff(_ other: FileExporterResultWithRemoved) -> StructDiff {
    return StructDiff()
      .add(diffProperty(other, \.result))
      .add(diffProperty(other, \.fileMarkedForDeletion))
      .add(diffProperty(other, \.runTime))
  }
}

public struct CopyFileResult: Sendable, Timeable {
  public let copied: Int
  public let markedForDeletion: Int
  public let runTime: Double

  static func empty() -> CopyFileResult {
    return CopyFileResult(copied: 0, markedForDeletion: 0, runTime: 0)
  }
}

public struct DeleteFileResult: Sendable, Timeable {
  public let deleted: Int
  public let runTime: Double

  static func empty() -> DeleteFileResult {
    return DeleteFileResult(deleted: 0, runTime: 0)
  }
}

public struct FileExporterStatus: Sendable {
  public let status: TaskStatus<FileExporterResultWithRemoved>
  public let copyStatus: TaskStatus<CopyFileResult>
  public let deleteStatus: TaskStatus<DeleteFileResult>

  public init(
    status: TaskStatus<FileExporterResultWithRemoved>,
    copyStatus: TaskStatus<CopyFileResult>,
    deleteStatus: TaskStatus<DeleteFileResult>,
  ) {
    self.status = status
    self.copyStatus = copyStatus
    self.deleteStatus = deleteStatus
  }

  public static func notStarted() -> FileExporterStatus {
    return FileExporterStatus(
      status: .notStarted,
      copyStatus: .notStarted,
      deleteStatus: .notStarted
    )
  }

  func copy(
    status: TaskStatus<FileExporterResultWithRemoved>? = nil,
    copyStatus: TaskStatus<CopyFileResult>? = nil,
    deleteStatus: TaskStatus<DeleteFileResult>? = nil,
  ) -> FileExporterStatus {
    return FileExporterStatus(
      status: status ?? self.status,
      copyStatus: copyStatus ?? self.copyStatus,
      deleteStatus: deleteStatus ?? self.deleteStatus,
    )
  }

  func withMainStatus(_ newStatus: TaskStatus<FileExporterResultWithRemoved>) -> FileExporterStatus {
    return copy(
      status: newStatus,
    )
  }

  func withCopyStatus(_ newStatus: TaskStatus<CopyFileResult>) -> FileExporterStatus {
    return copy(
      copyStatus: newStatus,
    )
  }

  func withDeleteStatus(_ newStatus: TaskStatus<DeleteFileResult>) -> FileExporterStatus {
    return copy(
      deleteStatus: newStatus,
    )
  }
}
