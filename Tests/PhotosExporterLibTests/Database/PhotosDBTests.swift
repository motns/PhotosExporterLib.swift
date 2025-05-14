import Foundation
import Logging
import Testing
@testable import PhotosExporterLib

@Suite("Photos DB tests")
final class PhotosDBTests {
  let photosDB: PhotosDB

  init() throws {
    var logger = Logger(label: "io.motns.testing")
    logger.logLevel = .critical

    if let url = Bundle.module.url(forResource: "TestDB", withExtension: "sqlite") {
      self.photosDB = try PhotosDB(
        photosDBPath: url.absoluteString,
        logger: logger
      )
    } else {
      fatalError("Could not find TestDB in bundle")
    }
  }

  @Test("Get all Asset locations by ID")
  func getAllAssetLocationsById() async throws {
    let locationsById = try photosDB.getAllAssetLocationsById()

    let expected = [
      "A3891C03-91F5-4E01-B005-4E4F2DF63853": PostalAddress(
        street: "Thames Path",
        subLocality: "Lambeth",
        city: "London",
        subAdministrativeArea: "London",
        state: "England",
        postalCode: "SE1",
        country: "United Kingdom",
        isoCountryCode: "GB"
      ),
      "AEB097DA-DD3B-45E7-B19F-3F9145768E22": PostalAddress(
        street: "",
        subLocality: "Sant Antoni",
        city: "Alicante",
        subAdministrativeArea: "",
        state: "Alicante",
        postalCode: "03002",
        country: "Spain",
        isoCountryCode: "ES"
      ),
      "EF45AD5A-5DE3-430E-AD0E-E8EF1A7E7A15": PostalAddress(
        street: "Id Antall József rakpart",
        subLocality: "District V",
        city: "Budapest",
        subAdministrativeArea: "",
        state: "Budapest",
        postalCode: "1054",
        country: "Hungary",
        isoCountryCode: "HU"
      ),
      "FC48CB6F-9135-49AE-BB3C-2C11AC4CF97D": PostalAddress(
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
