import Foundation

struct TestHelpers {
  static func dateFromStr(_ strOpt: String?) -> Date? {
    let dateOpt: Date?
    if let str = strOpt, str != "" {
      let dateFormatter = DateFormatter()
      dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
      dateOpt = dateFormatter.date(from: str)
    } else {
      dateOpt = nil
    }

    return dateOpt
  }

  static func createTestDir() throws -> String {
    let testDir = "/tmp/" + UUID().uuidString

    var isDirectory: ObjCBool = false
    if !(FileManager.default.fileExists(
      atPath: testDir,
      isDirectory: &isDirectory
    ) && isDirectory.boolValue) {
      try FileManager.default.createDirectory(
        atPath: testDir,
        withIntermediateDirectories: true,
        attributes: nil
      )
    }

    return testDir
  }
}
