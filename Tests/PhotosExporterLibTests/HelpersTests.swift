import Foundation
import Testing
@testable import PhotosExporterLib

@Suite("File Helper tests")
struct FileHelperTests {
  @Test(arguments: [
    ("2025-04-15 10:30:05", Optional<String>.none, Optional<String>.none, "2025/2025-04"),
    ("2025-04-15 10:30:05", "Spain", Optional<String>.none, "2025/2025-04-spain"),
    ("2025-04-15 10:30:05", "Spain", "Dénia", "2025/2025-04-spain-denia"),
    ("2025-04-15 10:30:05", Optional<String>.none, "Dénia", "2025/2025-04-denia"),
  ])
  func pathForDateAndLocation(
    _ dateStrOpt: String,
    _ countryOpt: String?,
    _ cityOpt: String?,
    _ out: String
  ) {
    let dateOpt = TestHelpers.dateFromStr(dateStrOpt)
    let res = FileHelper.pathForDateAndLocation(dateOpt: dateOpt, countryOpt: countryOpt, cityOpt: cityOpt)
    #expect(res == out)
  }

  @Test(arguments: [
    ("IMG004.jpg", "2025-04-15 10:30:05", false, "20250415103005-img004.jpg"),
    ("IMG004.jpg", "2025-04-15 10:30:05", true, "20250415103005-img004_edited.jpg"),
    ("Peter's awesome image-1.jpg", "2025-04-15 10:30:05", false, "20250415103005-peters_awesome_image1.jpg"),
  ])
  func filenameWithDateAndEdited(
    _ fileName: String,
    _ dateStrOpt: String?,
    _ isEdited: Bool,
    _ out: String
  ) {
    let dateOpt = TestHelpers.dateFromStr(dateStrOpt)
    let res = FileHelper.filenameWithDateAndEdited(originalFileName: fileName, dateOpt: dateOpt, isEdited: isEdited)
    #expect(res == out)
  }

  @Test(arguments: [
    ("London", "london"),
    ("Dénia", "denia"),
    ("United Kingdom", "united_kingdom"),
    ("Saint John's Wood", "saint_johns_wood"),
  ])
  func normaliseForPath(_ input: String, _ out: String) {
    #expect(FileHelper.normaliseForPath(input) == out)
  }
}