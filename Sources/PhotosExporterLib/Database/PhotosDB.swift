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
import Contacts
import Foundation
import Logging
import GRDB

protocol PhotosDBProtocol {
  func getAllAssetScoresById() throws -> [String: Int64]
  func getAllAssetLocationsById() throws -> [String: PhotosDB.PostalAddress]
}

struct PhotosDB: PhotosDBProtocol {
  private let dbQueue: DatabaseQueue
  private let logger: ClassLogger

  public enum Error: Swift.Error {
    case connectionFailed(String)
    case invalidGeoDataForAsset(String)
  }

  public struct PostalAddress: Sendable, Equatable {
    let street: String
    let subLocality: String
    let city: String
    let subAdministrativeArea: String
    let state: String
    let postalCode: String
    let country: String
    let isoCountryCode: String
  }

  init(
    photosDBPath: URL,
    logger: Logger
  ) throws {
    self.logger = ClassLogger(className: "PhotosDB", logger: logger)

    do {
      self.logger.debug("Connecting to copy of Photos DB...")
      dbQueue = try DatabaseQueue(path: photosDBPath.path(percentEncoded: false))
      self.logger.debug("Connected to copy of Photos DB")
    } catch {
      self.logger.critical("Failed to connect to copy of Photos DB")
      throw Error.connectionFailed("\(error)")
    }
  }

  func getAllAssetScoresById() throws -> [String: Int64] {
    logger.debug("Loading Asset scores from Photos SQLite DB...")
    var scoreById = [String: Int64]()

    try dbQueue.read { db in
      try Row.fetchAll(
        db,
        sql: """
        SELECT
          ZUUID AS uuid,
          CAST(ZOVERALLAESTHETICSCORE * 1000000000 AS INTEGER) AS score
        FROM ZASSET
        """,
      ).forEach { row in
        if let score = row["score"] as? Int64 {
          scoreById[row["uuid"]] = score
        }
      }
    }

    return scoreById
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
        """,
      ).forEach { row in
        let uuid: String = row["uuid"]

        if let data = row["location_blob"] as? Data {
          let postalAddressOpt = try decodePostalAddress(data: data)

          guard let postalAddress = postalAddressOpt else {
            logger.error(
              "Location data for Asset invalid",
              ["asset_id": "\(uuid)"]
            )
            throw Error.invalidGeoDataForAsset(uuid)
          }

          locationById[uuid] = postalAddress
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

  private func decodePostalAddress(data: Data) throws -> PostalAddress? {
    let geoInfoOpt = try NSKeyedUnarchiver.unarchivedObject(
      ofClass: PLRevGeoLocationInfo.self, from: data
    )

    guard let geoInfo = geoInfoOpt else {
      return nil
    }

    let pa = geoInfo.postalAddress
    return PostalAddress(
      street: pa.street,
      subLocality: pa.subLocality,
      city: pa.city,
      subAdministrativeArea: pa.subAdministrativeArea,
      state: pa.state,
      postalCode: pa.postalCode,
      country: pa.country,
      isoCountryCode: pa.isoCountryCode
    )
  }
}

/*
This is a copy of a subset of attributes from the private class with the same name in the
Apple private framework used by Photos. We'll use it to decode the reverse geolocation info
stored in the Photos SQLite DB.
*/
class PLRevGeoLocationInfo: NSObject, NSSecureCoding {
  static let supportsSecureCoding: Bool = true

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
