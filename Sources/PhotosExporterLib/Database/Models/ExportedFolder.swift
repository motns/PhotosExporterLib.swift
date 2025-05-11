import Foundation
import GRDB

struct ExportedFolder: Codable, Equatable, Hashable {
  let id: String
  let name: String
  let parentId: String?

  enum CodingKeys: String, CodingKey {
    case id, name
    case parentId = "parent_id"
  }

  func needsUpdate(_ other: ExportedFolder) -> Bool {
    return self.name != other.name || self.parentId != other.parentId
  }

  func updated(_ other: ExportedFolder) -> ExportedFolder {
    return self.copy(
      name: other.name,
      parentId: other.parentId
    )
  }

  func copy(
    id: String? = nil,
    name: String? = nil,
    parentId: String?? = nil
  ) -> ExportedFolder {
    return ExportedFolder(
      id: id ?? self.id,
      name: name ?? self.name,
      parentId: parentId ?? self.parentId
    )
  }

  static func fromPhotokitFolder(folder: PhotokitFolder) -> ExportedFolder {
    return ExportedFolder(
      id: folder.id,
      name: folder.title,
      parentId: folder.parentId
    )
  }
}

extension ExportedFolder: Identifiable, TableRecord, PersistableRecord, FetchableRecord {
  static let databaseTableName = "album_folder"

  enum Col {
    static let id = Column(CodingKeys.id)
    static let name = Column(CodingKeys.name)
    static let parentId = Column(CodingKeys.parentId)
  }
}