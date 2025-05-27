import Foundation

struct PhotokitFolder: Sendable {
  let id: String
  let title: String
  let subfolders: [PhotokitFolder]
  let albums: [PhotokitAlbum]

  func copy(
    id: String? = nil,
    title: String? = nil,
    subfolders: [PhotokitFolder]? = nil,
    albums: [PhotokitAlbum]? = nil,
  ) -> PhotokitFolder {
    return PhotokitFolder(
      id: id ?? self.id,
      title: title ?? self.title,
      subfolders: subfolders ?? self.subfolders,
      albums: albums ?? self.albums
    )
  }
}
