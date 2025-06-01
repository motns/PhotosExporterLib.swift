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
@testable import PhotosExporterLib

struct Diff {
  static func getDiffAsString<T: Diffable>(_ lhs: [T], _ rhs: [T]) -> String? {
    var leftIterator = lhs.enumerated().makeIterator()
    var rightIterator = rhs.enumerated().makeIterator()

    let out = getDiffAsString(
      leftIterator: &leftIterator,
      rightIterator: &rightIterator,
    )

    if out == "" {
      return nil
    } else {
      return """
      Lists did not match:
        \(StringHelper.indent(out, 2))
      """
    }
  }

  private static func getDiffAsString<EL: Diffable>(
    leftIterator: inout EnumeratedSequence<[EL]>.Iterator,
    rightIterator: inout EnumeratedSequence<[EL]>.Iterator,
    result: String = "",
  ) -> String {
    let leftOpt = leftIterator.next()
    let rightOpt = rightIterator.next()

    switch (leftOpt, rightOpt) {
    case (nil, nil): return result // We're finished
    case (let .some((idx, lhs)), nil):
      return getDiffAsString(
        leftIterator: &leftIterator,
        rightIterator: &rightIterator,
        result: result + String(describing: DiffRemovedElement(idx, lhs))
      )

    case (nil, let .some((idx, rhs))):
      return getDiffAsString(
        leftIterator: &leftIterator,
        rightIterator: &rightIterator,
        result: result + String(describing: DiffAddedElement(idx, rhs))
      )

    case (let .some((idx, lhs)), let .some((_, rhs))):
      let out: String
      if let diff = lhs.getDiffAsString(rhs) {
        out = """
        Changed at \(idx):
          \(StringHelper.indent(diff, 2))\n
        """
      } else {
        out = ""
      }

      return getDiffAsString(
        leftIterator: &leftIterator,
        rightIterator: &rightIterator,
        result: result + out
      )

    }
  }
}

private struct DiffAddedElement<EL>: CustomStringConvertible {
  let index: Int
  let element: EL

  init(_ index: Int, _ element: EL) {
    self.index = index
    self.element = element
  }

  var description: String {
    """
    Added in Right at \(index):
      \(StringHelper.indent(String(describing: element)))\n
    """
  }
}

private struct DiffRemovedElement<EL>: CustomStringConvertible {
  let index: Int
  let element: EL

  init(_ index: Int, _ element: EL) {
    self.index = index
    self.element = element
  }

  var description: String {
    """
    Missing from Right at \(index):
      \(StringHelper.indent(String(describing: element)))\n
    """
  }
}

protocol Diffable: Equatable {
  func getDiffAsString(_ other: Self) -> String?
}

protocol DiffableStruct {}

extension DiffableStruct {
  func propertyDiff<T: Equatable>(_ key: String, _ lhs: T, _ rhs: T) -> String? {
    if lhs == rhs {
      return nil
    } else {
      return """
      \(key):
        Left: \(lhs)
        Right: \(rhs)\n
      """
    }
  }

  func propertyDiff<T: Equatable>(_ key: String, _ lhs: T, _ rhs: T, comparator: (T, T) -> Bool) -> String? {
    if comparator(lhs, rhs) {
      return nil
    } else {
      return """
      \(key):
        Left: \(lhs)
        Right: \(rhs)\n
      """
    }
  }
}

extension ExportedAsset: Diffable, DiffableStruct {
  func getDiffAsString(_ other: ExportedAsset) -> String? {
    var out = ""
    out += propertyDiff("id", self.id, other.id) ?? ""
    out += propertyDiff("assetType", self.assetType, other.assetType) ?? ""
    out += propertyDiff("assetLibrary", self.assetLibrary, other.assetLibrary) ?? ""
    out += propertyDiff("createdAt", self.createdAt, other.createdAt) { lhs, rhs in
      DateHelper.secondsEquals(lhs, rhs)
    } ?? ""
    out += propertyDiff("updatedAt", self.updatedAt, other.updatedAt) { lhs, rhs in
      DateHelper.secondsEquals(lhs, rhs)
    } ?? ""
    out += propertyDiff("importedAt", self.importedAt, other.importedAt) { lhs, rhs in
      DateHelper.secondsEquals(lhs, rhs)
    } ?? ""
    out += propertyDiff("isFavourite", self.isFavourite, other.isFavourite) ?? ""
    out += propertyDiff("geoLat", self.geoLat, other.geoLat) ?? ""
    out += propertyDiff("geoLong", self.geoLong, other.geoLong) ?? ""
    out += propertyDiff("cityId", self.cityId, other.cityId) ?? ""
    out += propertyDiff("countryId", self.countryId, other.countryId) ?? ""
    out += propertyDiff("aestheticScore", self.aestheticScore, other.aestheticScore) ?? ""
    out += propertyDiff("isDeleted", self.isDeleted, other.isDeleted) ?? ""
    out += propertyDiff("deletedAt", self.deletedAt, other.deletedAt) { lhs, rhs in
      DateHelper.secondsEquals(lhs, rhs)
    } ?? ""
    return out != "" ? out : nil
  }
}

extension ExportedFile: Diffable, DiffableStruct {
  func getDiffAsString(_ other: ExportedFile) -> String? {
    var out = ""
    out += propertyDiff("id", self.id, other.id) ?? ""
    out += propertyDiff("fileType", self.fileType, other.fileType) ?? ""
    out += propertyDiff("originalFileName", self.originalFileName, other.originalFileName) ?? ""
    out += propertyDiff("fileSize", self.fileSize, other.fileSize) ?? ""
    out += propertyDiff("pixelHeight", self.pixelHeight, other.pixelHeight) ?? ""
    out += propertyDiff("pixelWidth", self.pixelWidth, other.pixelWidth) ?? ""
    out += propertyDiff("importedAt", self.importedAt, other.importedAt) { lhs, rhs in
      DateHelper.secondsEquals(lhs, rhs)
    } ?? ""
    out += propertyDiff("importedFileDir", self.importedFileDir, other.importedFileDir) ?? ""
    out += propertyDiff("importedFileName", self.importedFileName, other.importedFileName) ?? ""
    out += propertyDiff("wasCopied", self.wasCopied, other.wasCopied) ?? ""
    return out != "" ? out : nil
  }
}

extension ExportedFileWithLocation: Diffable, DiffableStruct {
  func getDiffAsString(_ other: ExportedFileWithLocation) -> String? {
    var out = ""
    if let diff = self.exportedFile.getDiffAsString(other.exportedFile) {
      out += diff
    }
    out += propertyDiff("createdAt", self.createdAt, other.createdAt) { lhs, rhs in
      DateHelper.secondsEquals(lhs, rhs)
    } ?? ""
    out += propertyDiff("country", self.country, other.country) ?? ""
    out += propertyDiff("city", self.city, other.city) ?? ""
    return out
  }
}

extension ExportedAssetFile: Diffable, DiffableStruct {
  func getDiffAsString(_ other: ExportedAssetFile) -> String? {
    var out = ""
    out += propertyDiff("assetId", self.assetId, other.assetId) ?? ""
    out += propertyDiff("fileId", self.fileId, other.fileId) ?? ""
    out += propertyDiff("isDeleted", self.isDeleted, other.isDeleted) ?? ""
    out += propertyDiff("deletedAt", self.deletedAt, other.deletedAt) { lhs, rhs in
      DateHelper.secondsEquals(lhs, rhs)
    } ?? ""
    return out != "" ? out : nil
  }
}

extension ExportedFolder: Diffable, DiffableStruct {
  func getDiffAsString(_ other: ExportedFolder) -> String? {
    var out = ""
    out += propertyDiff("id", self.id, other.id) ?? ""
    out += propertyDiff("name", self.name, other.name) ?? ""
    out += propertyDiff("parentId", self.parentId, other.parentId) ?? ""
    return out != "" ? out : nil
  }
}

extension ExportedAlbum: Diffable, DiffableStruct {
  func getDiffAsString(_ other: ExportedAlbum) -> String? {
    var out = ""
    out += propertyDiff("id", self.id, other.id) ?? ""
    out += propertyDiff("albumType", self.albumType, other.albumType) ?? ""
    out += propertyDiff("albumFolderId", self.albumFolderId, other.albumFolderId) ?? ""
    out += propertyDiff("name", self.name, other.name) ?? ""
    out += propertyDiff("assetIds", self.assetIds, other.assetIds) ?? ""
    return out != "" ? out : nil
  }
}

extension AssetExportResult: Diffable, DiffableStruct {
  func getDiffAsString(_ other: AssetExportResult) -> String? {
    var out = ""
    out += propertyDiff("assetInserted", self.assetInserted, other.assetInserted) ?? ""
    out += propertyDiff("assetUpdated", self.assetUpdated, other.assetUpdated) ?? ""
    out += propertyDiff("assetUnchanged", self.assetUnchanged, other.assetUnchanged) ?? ""
    out += propertyDiff("assetSkipped", self.assetSkipped, other.assetSkipped) ?? ""
    out += propertyDiff("assetMarkedForDeletion", self.assetMarkedForDeletion, other.assetMarkedForDeletion) ?? ""
    out += propertyDiff("assetDeleted", self.assetDeleted, other.assetDeleted) ?? ""
    out += propertyDiff("fileInserted", self.fileInserted, other.fileInserted) ?? ""
    out += propertyDiff("fileUpdated", self.fileUpdated, other.fileUpdated) ?? ""
    out += propertyDiff("fileUnchanged", self.fileUnchanged, other.fileUnchanged) ?? ""
    out += propertyDiff("fileSkipped", self.fileSkipped, other.fileSkipped) ?? ""
    out += propertyDiff("fileMarkedForDeletion", self.fileMarkedForDeletion, other.fileMarkedForDeletion) ?? ""
    out += propertyDiff("fileDeleted", self.fileDeleted, other.fileDeleted) ?? ""
    return out != "" ? out : nil
  }
}

extension CollectionExportResult: Diffable, DiffableStruct {
  func getDiffAsString(_ other: CollectionExportResult) -> String? {
    var out = ""
    out += propertyDiff("folderInserted", self.folderInserted, other.folderInserted) ?? ""
    out += propertyDiff("folderUpdated", self.folderUpdated, other.folderUpdated) ?? ""
    out += propertyDiff("folderUnchanged", self.folderUnchanged, other.folderUnchanged) ?? ""
    out += propertyDiff("albumInserted", self.albumInserted, other.albumInserted) ?? ""
    out += propertyDiff("albumUpdated", self.albumUpdated, other.albumUpdated) ?? ""
    out += propertyDiff("albumUnchanged", self.albumUnchanged, other.albumUnchanged) ?? ""
    return out != "" ? out : nil
  }
}

extension FileExportResult: Diffable, DiffableStruct {
  func getDiffAsString(_ other: FileExportResult) -> String? {
    var out = ""
    out += propertyDiff("copied", self.copied, other.copied) ?? ""
    out += propertyDiff("deleted", self.deleted, other.deleted) ?? ""
    return out != "" ? out : nil
  }
}

extension ExportResult: Diffable, DiffableStruct {
  func getDiffAsString(_ other: ExportResult) -> String? {
    var out = ""
    if let diff = self.assetExport.getDiffAsString(other.assetExport) {
      out += diff
    }
    if let diff = self.collectionExport.getDiffAsString(other.collectionExport) {
      out += diff
    }
    if let diff = self.fileExport.getDiffAsString(other.fileExport) {
      out += diff
    }
    return out != "" ? out : nil
  }
}

extension ExportResultHistoryEntry: Diffable, DiffableStruct {
  func getDiffAsString(_ other: ExportResultHistoryEntry) -> String? {
    var out = ""
    out += propertyDiff("id", self.id, other.id) ?? ""
    out += propertyDiff("createdAt", self.createdAt, other.createdAt) { lhs, rhs in
      DateHelper.secondsEquals(lhs, rhs)
    } ?? ""
    if let diff = self.exportResult.getDiffAsString(other.exportResult) {
      out += diff
    }
    out += propertyDiff("asset_count", self.assetCount, other.assetCount) ?? ""
    out += propertyDiff("file_count", self.fileCount, other.fileCount) ?? ""
    out += propertyDiff("album_count", self.albumCount, other.albumCount) ?? ""
    out += propertyDiff("folder_count", self.folderCount, other.folderCount) ?? ""
    return out != "" ? out : nil
  }
}

extension HistoryEntry: Diffable, DiffableStruct {
  func getDiffAsString(_ other: HistoryEntry) -> String? {
    var out = ""
    out += propertyDiff("id", self.id, other.id) ?? ""
    out += propertyDiff("createdAt", self.createdAt, other.createdAt) { lhs, rhs in
      DateHelper.secondsEquals(lhs, rhs)
    } ?? ""
    if let diff = self.exportResult.getDiffAsString(other.exportResult) {
      out += diff
    }
    out += propertyDiff("asset_count", self.assetCount, other.assetCount) ?? ""
    out += propertyDiff("file_count", self.fileCount, other.fileCount) ?? ""
    out += propertyDiff("album_count", self.albumCount, other.albumCount) ?? ""
    out += propertyDiff("folder_count", self.folderCount, other.folderCount) ?? ""
    return out != "" ? out : nil
  }
}

extension HistoryEntry: Equatable {
  public static func == (lhs: HistoryEntry, rhs: HistoryEntry) -> Bool {
    return lhs.id == rhs.id
      && DateHelper.secondsEquals(lhs.createdAt, rhs.createdAt)
      && lhs.exportResult == rhs.exportResult
      && lhs.assetCount == rhs.assetCount
      && lhs.fileCount == rhs.fileCount
      && lhs.albumCount == rhs.albumCount
      && lhs.folderCount == rhs.folderCount
  }
}
