import GRDB

// Used for querying only - doesn't map to a database table
struct ExportedFileWithAssetIds: Decodable, FetchableRecord, Hashable {
  let exportedFile: ExportedFile
  let assetIds: [String]

  enum CodingKeys: String, CodingKey {
    case exportedFile
    case assetIds = "asset_ids"
  }
}
