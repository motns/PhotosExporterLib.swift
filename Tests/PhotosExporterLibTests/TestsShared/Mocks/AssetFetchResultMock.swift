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

class AssetFetchResultMock: AssetFetchResultProtocol {
  private var elements: [PhotokitAsset]
  private var index: Int
  public let count: Int

  init(_ elements: [PhotokitAsset]) {
    self.elements = elements
    self.index = 0
    self.count = elements.count
  }

  func reset() {
    self.index = 0
  }

  func hasNext() -> Bool {
    return index < count
  }

  func next() async throws -> PhotokitAsset? {
    guard index < count else {
      return nil
    }
    let element = elements[index]
    index += 1
    return element
  }
}
