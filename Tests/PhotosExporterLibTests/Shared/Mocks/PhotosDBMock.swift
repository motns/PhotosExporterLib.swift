@testable import PhotosExporterLib

class PhotosDBMock: PhotosDBProtocol {
  var assetLocations: [String: PostalAddress]
  var assetScores: [String: Int64]

  init() {
    self.assetLocations = [:]
    self.assetScores = [:]
  }

  func getAllAssetScoresById() throws -> [String: Int64] {
    return assetScores
  }

  func getAllAssetLocationsById() throws -> [String: PostalAddress] {
    return assetLocations
  }
}
