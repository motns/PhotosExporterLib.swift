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

extension PhotokitFolder: DiffableStruct {
  func getStructDiff(_ other: PhotokitFolder) -> StructDiff {
    return StructDiff()
      .add(diffProperty(other, \.id))
      .add(diffProperty(other, \.title))
      .add(diffProperty(other, \.subfolders))
      .add(diffProperty(other, \.albums))
  }
}
