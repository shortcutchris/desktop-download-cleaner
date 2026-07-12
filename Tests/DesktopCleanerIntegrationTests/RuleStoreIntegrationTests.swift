import DesktopCleanerCore
import DesktopCleanerServices
import Foundation
import XCTest

final class RuleStoreIntegrationTests: XCTestCase {
    func testSaveExportImportRoundTripUsesOnlyTemporaryDirectory() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("DesktopCleanerRules-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let storeURL = root.appendingPathComponent("rules.json")
        let exportURL = root.appendingPathComponent("export.json")
        let store = RuleStore(fileURL: storeURL)
        let rules = [UserRule(
            name: "Screenshots",
            order: 0,
            condition: RuleCondition(kind: .filename, pattern: "Screenshot *"),
            category: .screenshots,
            basenameTemplate: "{basename}"
        )]

        try await store.save(rules)
        let loaded = try await store.load()
        XCTAssertEqual(loaded, rules)
        try await store.export(rules, to: exportURL)
        let imported = try await store.importRules(from: exportURL)
        XCTAssertEqual(imported, rules)
    }
}
