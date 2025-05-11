import Contacts
import Foundation
import Logging
import GRDB

protocol PhotosDBProtocol: Actor {
  func getAllAssetLocationsById() async throws -> [String: PostalAddress]
}

actor PhotosDB: PhotosDBProtocol {
  private let dbQueue: DatabaseQueue
  private let logger: ClassLogger

  init(
    photosDBPath: String,
    logger: Logger
  ) throws {
    self.logger = ClassLogger(logger: logger, className: "PhotosDB")

    do {
      self.logger.debug("Connecting to copy of Photos DB...")
      dbQueue = try DatabaseQueue(path: photosDBPath)
      self.logger.debug("Connected to copy of Photos DB")
    } catch {
      self.logger.critical("Failed to connect to copy of Photos DB")
      throw PhotosDBError.connectionFailed("\(error)")
    }
  }

  func getAllAssetLocationsById() throws -> [String: PostalAddress] {
    logger.debug("Loading Asset locations from Photos SQLite DB...")

    var locationById = [String: PostalAddress]()

    try dbQueue.read { db in
      NSKeyedUnarchiver.setClass(PLRevGeoLocationInfo.self, forClassName: "PLRevGeoLocationInfo")

      try Row.fetchAll(
        db,
        sql: """
        SELECT
          asset.ZUUID AS uuid,
          attributes.ZREVERSELOCATIONDATA AS location_blob
        FROM ZADDITIONALASSETATTRIBUTES AS attributes
          JOIN ZASSET AS asset ON attributes.ZASSET = asset.Z_PK
        WHERE attributes.ZREVERSELOCATIONDATAISVALID = 1
        """
      ).forEach { row in
        let uuid: String = row["uuid"]

        if let data = row["location_blob"] as? Data {
          let geoInfoOpt = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: PLRevGeoLocationInfo.self, from: data
          )

          if let geoInfo = geoInfoOpt {
            let pa = geoInfo.postalAddress
            locationById[uuid] = PostalAddress(
              street: pa.street,
              subLocality: pa.subLocality,
              city: pa.city,
              subAdministrativeArea: pa.subAdministrativeArea,
              state: pa.state,
              postalCode: pa.postalCode,
              country: pa.country,
              isoCountryCode: pa.isoCountryCode
            )

            logger.trace(
              "Decoded location data for Asset",
              [
                "asset_id": "\(uuid)",
                "country": "\(geoInfo.postalAddress.country)",
                "city": "\(geoInfo.postalAddress.city)",
              ]
            )
          } else {
            logger.error(
              "Location data for Asset invalid",
              ["asset_id": "\(uuid)"]
            )
            throw PhotosDBError.invalidGeoDataForAsset(uuid)
          }
        } else {
          logger.trace(
            "Location data for Asset is empty",
            ["asset_id": "\(uuid)"]
          )
        }
      }
    }

    return locationById
  }
}

enum PhotosDBError: Error {
  case connectionFailed(String)
  case invalidGeoDataForAsset(String)
}

struct PostalAddress: Sendable, Equatable {
  let street: String
  let subLocality: String
  let city: String
  let subAdministrativeArea: String
  let state: String
  let postalCode: String
  let country: String
  let isoCountryCode: String
}

/*
This is a copy of a subset of attributes from the private class with the same name in the
Apple private framework used by Photos. We'll use it to decode the reverse geolocation info
stored in the Photos SQLite DB.
*/
class PLRevGeoLocationInfo: NSObject, NSSecureCoding {
  static var supportsSecureCoding: Bool {
    return true
  }

  let postalAddress: CNPostalAddress

  required init?(coder: NSCoder) {
    guard let postalAddress = coder.decodeObject(of: CNPostalAddress.self, forKey: "postalAddress") else {
      return nil
    }
    self.postalAddress = postalAddress
    super.init()
  }

  func encode(with coder: NSCoder) {
    coder.encode(postalAddress, forKey: "postalAddress")
  }
}