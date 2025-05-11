import Foundation
import Logging

struct ClassLogger {
  private let logger: Logger
  private let globalMetadata: Logger.Metadata

  init(
    logger: Logger,
    className: String,
    metadata: Logger.Metadata? = nil
  ) {
    self.logger = logger

    let classMetadata: Logger.Metadata = ["class": "\(className)"]
    self.globalMetadata = if let metadata {
      metadata.merging(classMetadata) { (_, new) in new }
    } else {
      classMetadata
    }
  }

  private func logWithClassName(
    level: Logger.Level,
    msg: Logger.Message,
    metadataOpt: Logger.Metadata? = nil
  ) {
    let mergedMetadata: Logger.Metadata = if let metadata = metadataOpt {
      metadata.merging(globalMetadata) { (_, new) in new }
    } else {
      globalMetadata
    }

    logger.log(level: level, msg, metadata: mergedMetadata)
  }

  func log(_ level: Logger.Level, _ msg: Logger.Message, _ metadataOpt: Logger.Metadata? = nil) {
    logWithClassName(level: level, msg: msg, metadataOpt: metadataOpt)
  }

  func trace(_ msg: Logger.Message, _ metadataOpt: Logger.Metadata? = nil) {
    logWithClassName(level: .trace, msg: msg, metadataOpt: metadataOpt)
  }

  func debug(_ msg: Logger.Message, _ metadataOpt: Logger.Metadata? = nil) {
    logWithClassName(level: .debug, msg: msg, metadataOpt: metadataOpt)
  }

  func info(_ msg: Logger.Message, _ metadataOpt: Logger.Metadata? = nil) {
    logWithClassName(level: .info, msg: msg, metadataOpt: metadataOpt)
  }

  func notice(_ msg: Logger.Message, _ metadataOpt: Logger.Metadata? = nil) {
    logWithClassName(level: .notice, msg: msg, metadataOpt: metadataOpt)
  }

  func warning(_ msg: Logger.Message, _ metadataOpt: Logger.Metadata? = nil) {
    logWithClassName(level: .warning, msg: msg, metadataOpt: metadataOpt)
  }

  func error(_ msg: Logger.Message, _ metadataOpt: Logger.Metadata? = nil) {
    logWithClassName(level: .error, msg: msg, metadataOpt: metadataOpt)
  }

  func critical(_ msg: Logger.Message, _ metadataOpt: Logger.Metadata? = nil) {
    logWithClassName(level: .critical, msg: msg, metadataOpt: metadataOpt)
  }
}