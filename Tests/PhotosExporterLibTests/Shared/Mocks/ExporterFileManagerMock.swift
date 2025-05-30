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

struct CreateSymlinkCall: Hashable, Diffable, DiffableStruct {
  let src: URL
  let dest: URL

  func getDiffAsString(_ other: CreateSymlinkCall) -> String? {
    var out = ""
    out += propertyDiff("src", self.src, other.src) ?? ""
    out += propertyDiff("dest", self.dest, other.dest) ?? ""
    return out != "" ? out : nil
  }
}

struct RemoveCall: Diffable, DiffableStruct {
  let url: URL

  func getDiffAsString(_ other: RemoveCall) -> String? {
    var out = ""
    out += propertyDiff("url", self.url, other.url) ?? ""
    return out != "" ? out : nil
  }
}
