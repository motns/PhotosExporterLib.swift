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

struct ClassLogger: Sendable {
  public let logger: Logger
  private let className: String
  private let globalMetadata: Logger.Metadata

  init(
    className: String,
    logger: Logger? = nil,
    metadata: Logger.Metadata? = nil,
  ) {
    if let customLogger = logger {
      self.logger = customLogger
    } else {
      var defaultLogger = Logger(label: "io.motns.PhotosExporter")
      defaultLogger.logLevel = .info
      self.logger = defaultLogger
    }

    self.className = className
    let classMetadata: Logger.Metadata = ["class": "\(className)"]
    self.globalMetadata = if let metadata {
      metadata.merging(classMetadata) { (_, new) in new }
    } else {
      classMetadata
    }
  }

  func withClassName(
    className: String,
  ) -> ClassLogger {
    return ClassLogger(
      className: className,
      logger: self.logger,
      metadata: self.globalMetadata, // "class" key will be overwritten by init()
    )
  }

  func withMetadata(
    metadata: Logger.Metadata,
  ) -> ClassLogger {
    return ClassLogger(
      className: self.className,
      logger: self.logger,
      metadata: metadata,
    )
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
