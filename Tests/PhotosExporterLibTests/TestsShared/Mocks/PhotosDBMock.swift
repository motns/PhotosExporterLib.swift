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

class PhotosDBMock: PhotosDBProtocol {
  var assetLocations: [String: PhotosDB.PostalAddress]
  var assetScores: [String: Int64]

  init() {
    self.assetLocations = [:]
    self.assetScores = [:]
  }

  func getAllAssetScoresById() throws -> [String: Int64] {
    return assetScores
  }

  func getAllAssetLocationsById() throws -> [String: PhotosDB.PostalAddress] {
    return assetLocations
  }
}
