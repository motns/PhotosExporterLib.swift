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
