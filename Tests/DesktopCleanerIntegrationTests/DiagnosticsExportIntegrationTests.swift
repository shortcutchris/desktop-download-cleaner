import DesktopCleanerCore
import DesktopCleanerServices
import Foundation
import XCTest

final class DiagnosticsExportIntegrationTests: XCTestCase {
    func testExportContainsOnlyRedactedAggregateData() throws {
        let service = DiagnosticsExportService()
        let input = DiagnosticsInput(
            appVersion: "1.0.0",
            buildNumber: "2",
            sourceCount: 3,
            sessionStateCounts: ["retained": 2],
            ruleCount: 4,
            exclusionCount: 1,
            hasAPIKey: true,
            aiPrivacyLevel: "metadataOnly",
            aiQuality: .balanced,
            operation: .move,
            minimumAgeDays: 7,
            menuBarEnabled: true,
            renamePreferences: RenamePreferences(namingStyle: .hyphenated),
            sessionRetention: .thirtyDays
        )
        let data = try service.reportData(for: input, generatedAt: Date(timeIntervalSince1970: 0))
        let text = String(decoding: data, as: UTF8.self)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopCleanerDiagnostics-\(UUID())", isDirectory: true)
        let destination = root.appendingPathComponent("diagnostics.json")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        try service.export(data, to: destination)

        XCTAssertTrue(text.contains("\"privateFileDataIncluded\" : false"))
        XCTAssertTrue(text.contains("\"apiKeyStored\" : true"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("filename"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("filepath"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("apiKeyValue" + "\" : \""))
        XCTAssertEqual(try Data(contentsOf: destination), data)
    }
}
