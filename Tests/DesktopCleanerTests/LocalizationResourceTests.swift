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

        XCTAssertGreaterThan(catalog.count, 460)
        XCTAssertEqual(catalog["Try Safe Demo"], "Sichere Demo ausprobieren")
        XCTAssertEqual(catalog["Settings…"], "Einstellungen…")
        XCTAssertEqual(catalog["Ready"], "Bereit")
        XCTAssertEqual(catalog["Documents"], "Dokumente")
        XCTAssertEqual(catalog["Help & Guide"], "Hilfe & Anleitung")
        XCTAssertEqual(catalog["Interactive Guided Tour"], "Interaktive Einführung")
        XCTAssertEqual(catalog["This tour is a simulation. It never reads, creates, moves, or deletes files."],
                       "Diese Einführung ist eine Simulation. Sie liest, erstellt, verschiebt oder löscht niemals Dateien.")

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

    func testBundledChangelogMatchesBuildAndGermanCatalog() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let changelogData = try Data(contentsOf: repositoryRoot.appendingPathComponent("Resources/AppChangelog.json"))
        let manifest = try JSONDecoder().decode(TestChangelogManifest.self, from: changelogData)
        let latest = try XCTUnwrap(manifest.releases.first)

        XCTAssertEqual(manifest.releases.count, 8)
        XCTAssertEqual(Set(manifest.releases.map(\.version)).count, manifest.releases.count)
        XCTAssertEqual(latest.version, "1.3.0")
        XCTAssertEqual(latest.build, "10")

        let project = try String(
            contentsOf: repositoryRoot.appendingPathComponent("project.yml"),
            encoding: .utf8
        )
        XCTAssertTrue(project.contains("MARKETING_VERSION: \"\(latest.version)\""))
        XCTAssertTrue(project.contains("CURRENT_PROJECT_VERSION: \"\(latest.build)\""))

        let germanData = try Data(contentsOf: repositoryRoot
            .appendingPathComponent("Resources/de.lproj/Localizable.strings"))
        let germanCatalog = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: germanData, format: nil) as? [String: String]
        )
        for release in manifest.releases {
            XCTAssertNotNil(germanCatalog[release.summaryKey], "Missing German summary for \(release.version)")
            XCTAssertFalse(release.sections.isEmpty, "Missing sections for \(release.version)")
            for section in release.sections {
                XCTAssertTrue(["added", "improved", "fixed", "security"].contains(section.kind))
                XCTAssertFalse(section.itemKeys.isEmpty, "Empty \(section.kind) section in \(release.version)")
                for key in section.itemKeys {
                    XCTAssertNotNil(germanCatalog[key], "Missing German changelog translation: \(key)")
                }
            }
        }
    }

    private func placeholders(in value: String) -> [String] {
        let expression = try! NSRegularExpression(pattern: "%@")
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return expression.matches(in: value, range: range).map { _ in "%@" }
    }
}

private struct TestChangelogManifest: Decodable {
    let releases: [TestChangelogRelease]
}

private struct TestChangelogRelease: Decodable {
    let version: String
    let build: String
    let summaryKey: String
    let sections: [TestChangelogSection]
}

private struct TestChangelogSection: Decodable {
    let kind: String
    let itemKeys: [String]
}
