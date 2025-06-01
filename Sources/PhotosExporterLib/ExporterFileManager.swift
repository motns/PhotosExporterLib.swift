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

protocol ExporterFileManagerProtocol {
  func createDirectory(url: URL) throws -> FileOperationResult
  func createDirectory(path: String) throws -> FileOperationResult
  func createSymlink(src: URL, dest: URL) throws -> FileOperationResult
  func remove(url: URL) throws -> FileOperationResult
}

struct ExporterFileManager: ExporterFileManagerProtocol {
  static let shared = ExporterFileManager()

  func createDirectory(url: URL) throws -> FileOperationResult {
    return try createDirectory(path: url.path(percentEncoded: false))
  }

  func createDirectory(path: String) throws -> FileOperationResult {
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(
      atPath: path,
      isDirectory: &isDirectory
    ) && !isDirectory.boolValue {
      throw FileHelperError.fileExistsAtDirectoryPath(path)
    }

    guard !FileManager.default.fileExists(atPath: path) else {
      return .exists
    }

    try FileManager.default.createDirectory(
      atPath: path,
      withIntermediateDirectories: true,
      attributes: nil
    )
    return .success
  }

  func createSymlink(src: URL, dest: URL) throws -> FileOperationResult {
    guard !FileManager.default.fileExists(atPath: dest.path(percentEncoded: false)) else {
      return .exists
    }
    try FileManager.default.createSymbolicLink(at: dest, withDestinationURL: src)
    return .success
  }

  func remove(url: URL) throws -> FileOperationResult {
    guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
      return .notexists
    }

    try FileManager.default.removeItem(atPath: url.path(percentEncoded: false))
    return .success
  }
}

enum FileOperationResult {
  case exists, notexists, success
}
