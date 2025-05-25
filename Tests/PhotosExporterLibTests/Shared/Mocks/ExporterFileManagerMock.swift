import Foundation
@testable import PhotosExporterLib

class ExporterFileManagerMock: ExporterFileManagerProtocol {
  public private(set) var createSymlinkCalls: [CreateSymlinkCall]

  init() {
    createSymlinkCalls = [CreateSymlinkCall]()
  }

  func resetCalls() {
    createSymlinkCalls = []
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
    return try ExporterFileManager.shared.remove(url: url)
  }
}

struct CreateSymlinkCall: Hashable {
  let src: URL
  let dest: URL
}
