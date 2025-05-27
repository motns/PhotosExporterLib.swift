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
      DateHelper.safeEquals(lhs, rhs)
    } ?? ""
    out += propertyDiff("updatedAt", self.updatedAt, other.updatedAt) { lhs, rhs in
      DateHelper.safeEquals(lhs, rhs)
    } ?? ""
    out += propertyDiff("importedAt", self.importedAt, other.importedAt) { lhs, rhs in
      DateHelper.safeEquals(lhs, rhs)
    } ?? ""
    out += propertyDiff("isFavourite", self.isFavourite, other.isFavourite) ?? ""
    out += propertyDiff("geoLat", self.geoLat, other.geoLat) ?? ""
    out += propertyDiff("geoLong", self.geoLong, other.geoLong) ?? ""
    out += propertyDiff("cityId", self.cityId, other.cityId) ?? ""
    out += propertyDiff("countryId", self.countryId, other.countryId) ?? ""
    out += propertyDiff("isDeleted", self.isDeleted, other.isDeleted) ?? ""
    out += propertyDiff("deletedAt", self.deletedAt, other.deletedAt) { lhs, rhs in
      DateHelper.safeEquals(lhs, rhs)
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
    out += propertyDiff("importedAt", self.importedAt, other.importedAt) { lhs, rhs in
      DateHelper.safeEquals(lhs, rhs)
    } ?? ""
    out += propertyDiff("importedFileDir", self.importedFileDir, other.importedFileDir) ?? ""
    out += propertyDiff("importedFileName", self.importedFileName, other.importedFileName) ?? ""
    out += propertyDiff("wasCopied", self.wasCopied, other.wasCopied) ?? ""
    return out != "" ? out : nil
  }
}

extension ExportedAssetFile: Diffable, DiffableStruct {
  func getDiffAsString(_ other: ExportedAssetFile) -> String? {
    var out = ""
    out += propertyDiff("assetId", self.assetId, other.assetId) ?? ""
    out += propertyDiff("fileId", self.fileId, other.fileId) ?? ""
    out += propertyDiff("isDeleted", self.isDeleted, other.isDeleted) ?? ""
    out += propertyDiff("deletedAt", self.deletedAt, other.deletedAt) { lhs, rhs in
      DateHelper.safeEquals(lhs, rhs)
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
    out += propertyDiff("fileInserted", self.fileInserted, other.fileInserted) ?? ""
    out += propertyDiff("fileUpdated", self.fileUpdated, other.fileUpdated) ?? ""
    out += propertyDiff("fileUnchanged", self.fileUnchanged, other.fileUnchanged) ?? ""
    out += propertyDiff("fileSkipped", self.fileSkipped, other.fileSkipped) ?? ""
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

extension FileCopyResult: Diffable, DiffableStruct {
  func getDiffAsString(_ other: FileCopyResult) -> String? {
    var out = ""
    out += propertyDiff("copied", self.copied, other.copied) ?? ""
    out += propertyDiff("removed", self.removed, other.removed) ?? ""
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
    if let diff = self.fileCopy.getDiffAsString(other.fileCopy) {
      out += diff
    }
    return out != "" ? out : nil
  }
}
