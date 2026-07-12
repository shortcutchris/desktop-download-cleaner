import Foundation
import XCTest

final class LocalizationResourceTests: XCTestCase {
    func testGermanCatalogIsCompleteAndFormatCompatible() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let germanURL = repositoryRoot
            .appendingPathComponent("Resources/de.lproj/Localizable.strings")
        let data = try Data(contentsOf: germanURL)
        let catalog = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
        )

        XCTAssertGreaterThan(catalog.count, 250)
        XCTAssertEqual(catalog["Try Safe Demo"], "Sichere Demo ausprobieren")
        XCTAssertEqual(catalog["Settings…"], "Einstellungen…")
        XCTAssertEqual(catalog["Ready"], "Bereit")
        XCTAssertEqual(catalog["Documents"], "Dokumente")

        for (key, value) in catalog {
            XCTAssertFalse(value.isEmpty, "Empty German translation for \(key)")
            XCTAssertEqual(
                placeholders(in: key),
                placeholders(in: value),
                "Format placeholders differ for \(key)"
            )
        }

        for languageCode in ["en", "de"] {
            let resourceURL = repositoryRoot
                .appendingPathComponent("Resources/\(languageCode).lproj/Localizable.strings")
            XCTAssertTrue(FileManager.default.fileExists(atPath: resourceURL.path))
        }
    }

    private func placeholders(in value: String) -> [String] {
        let expression = try! NSRegularExpression(pattern: "%@")
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return expression.matches(in: value, range: range).map { _ in "%@" }
    }
}
