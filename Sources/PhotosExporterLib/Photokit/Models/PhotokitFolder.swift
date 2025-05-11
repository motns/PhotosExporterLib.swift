import Foundation

struct PhotokitFolder: Sendable {
  let id: String
  let title: String
  let parentId: String?
  let subfolders: [PhotokitFolder]
  let albums: [PhotokitAlbum]
}