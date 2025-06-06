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
@testable import PhotosExporterLib

class ExporterFileManagerMock: ExporterFileManagerProtocol {
  public private(set) var createSymlinkCalls: [CreateSymlinkCall]
  public private(set) var removeCalls: [RemoveCall]

  init() {
    createSymlinkCalls = [CreateSymlinkCall]()
    removeCalls = [RemoveCall]()
  }

  func resetCalls() {
    createSymlinkCalls = []
    removeCalls = []
  }

  func createDirectory(url: URL) throws -> FileOperationResult {
    return try ExporterFileManager.shared.createDirectory(url: url)
  }

  func createDirectory(path: String) throws -> FileOperationResult {
    return try ExporterFileManager.shared.createDirectory(path: path)
  }

  func createSymlink(src: URL, dest: URL) throws -> FileOperationResult {
    createSymlinkCalls.append(CreateSymlinkCall(src: src, dest: dest))
    return .success
  }

  func remove(url: URL) throws -> FileOperationResult {
    removeCalls.append(RemoveCall(url: url))
    return try ExporterFileManager.shared.remove(url: url)
  }
}

struct CreateSymlinkCall: DiffableStruct {
  let src: URL
  let dest: URL

  func getStructDiff(_ other: CreateSymlinkCall) -> StructDiff {
    return StructDiff()
      .add(diffProperty(other, \.src))
      .add(diffProperty(other, \.dest))
  }
}

struct RemoveCall: DiffableStruct {
  let url: URL

  func getStructDiff(_ other: RemoveCall) -> StructDiff {
    return StructDiff()
      .add(diffProperty(other, \.url))
  }
}
