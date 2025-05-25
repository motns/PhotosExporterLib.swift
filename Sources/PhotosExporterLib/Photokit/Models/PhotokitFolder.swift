import Foundation

struct PhotokitFolder: Sendable {
  let id: String
  let title: String
  let subfolders: [PhotokitFolder]
  let albums: [PhotokitAlbum]
}
