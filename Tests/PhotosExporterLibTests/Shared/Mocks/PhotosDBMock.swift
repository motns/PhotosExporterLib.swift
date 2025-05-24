@testable import PhotosExporterLib

class PhotosDBMock: PhotosDBProtocol {
  var assetLocations: [String: PostalAddress]

  init() {
    self.assetLocations = [:]
  }

  func getAllAssetLocationsById() throws -> [String: PostalAddress] {
    return assetLocations
  }
}
