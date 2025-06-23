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
import Logging
import Testing
@testable import PhotosExporterLib

// There's some strange behaviour whereby for some reason the shared SQLite DB
// is locked when these tests are run, so let's just run them serially for now
@Suite("Photos DB tests", .serialized)
final class PhotosDBTests {
  let photosDB: PhotosDB

  init() throws {
    var logger = Logger(label: "io.motns.testing")
    logger.logLevel = .critical

    if let url = Bundle.module.url(forResource: "TestDB", withExtension: "sqlite") {
      self.photosDB = try PhotosDB(
        photosDBPath: url,
        logger: logger
      )
    } else {
      fatalError("Could not find TestDB in bundle")
    }
  }

  @Test("Get all Asset scores by ID", .enabled(if: true))
  func getAllAssetScoresById() throws {
    let scoresById = try photosDB.getAllAssetScoresById()

    let expected: [String: Int64] = [
      "5DA77F31-E9E4-4613-BEAA-BA158E06FD0E": 500000000,
      "A3CE313C-284F-4679-AE85-B89192DFCC8C": 500000000,
      "8D3CC9F7-FAAA-4B04-A742-9669B75DECFC": 500000000,
      "EA469F78-2332-425D-B3C0-51C93E78C112": 500000000,
      "AEB097DA-DD3B-45E7-B19F-3F9145768E22": 702561736,
      "FC48CB6F-9135-49AE-BB3C-2C11AC4CF97D": 808547258,
      "A3891C03-91F5-4E01-B005-4E4F2DF63853": 814257144,
      "EF45AD5A-5DE3-430E-AD0E-E8EF1A7E7A15": 830729365,
    ]
    #expect(scoresById == expected)
  }

  @Test("Get all Asset locations by ID")
  func getAllAssetLocationsById() throws {
    let locationsById = try photosDB.getAllAssetLocationsById()

    let expected = [
      "A3891C03-91F5-4E01-B005-4E4F2DF63853": PhotosDB.PostalAddress(
        street: "Thames Path",
        subLocality: "Lambeth",
        city: "London",
        subAdministrativeArea: "London",
        state: "England",
        postalCode: "SE1",
        country: "United Kingdom",
        isoCountryCode: "GB"
      ),
      "AEB097DA-DD3B-45E7-B19F-3F9145768E22": PhotosDB.PostalAddress(
        street: "",
        subLocality: "Sant Antoni",
        city: "Alicante",
        subAdministrativeArea: "",
        state: "Alicante",
        postalCode: "03002",
        country: "Spain",
        isoCountryCode: "ES"
      ),
      "EF45AD5A-5DE3-430E-AD0E-E8EF1A7E7A15": PhotosDB.PostalAddress(
        street: "Id Antall József rakpart",
        subLocality: "District V",
        city: "Budapest",
        subAdministrativeArea: "",
        state: "Budapest",
        postalCode: "1054",
        country: "Hungary",
        isoCountryCode: "HU"
      ),
      "FC48CB6F-9135-49AE-BB3C-2C11AC4CF97D": PhotosDB.PostalAddress(
        street: "1–15 Lower New Change Passage",
        subLocality: "City of London",
        city: "London",
        subAdministrativeArea: "London",
        state: "England",
        postalCode: "EC4M",
        country: "United Kingdom",
        isoCountryCode: "GB"
      ),
    ]

    #expect(locationsById == expected)
  }
}
