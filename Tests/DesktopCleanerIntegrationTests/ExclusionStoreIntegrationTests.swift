import DesktopCleanerCore
import DesktopCleanerServices
import Foundation
import XCTest

final class ExclusionStoreIntegrationTests: XCTestCase {
    func testSaveAndLoadRoundTripUsesInjectedTemporaryFile() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopCleanerExclusions-\(UUID())", isDirectory: true)
        let fileURL = root.appendingPathComponent("nested/exclusions.json")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let exclusions = [
            ExclusionRule(kind: .filename, pattern: "*.tmp"),
            ExclusionRule(kind: .relativePath, pattern: "Private/*")
        ]
        let store = ExclusionStore(fileURL: fileURL)

        try await store.save(exclusions)

        let loaded = try await store.load()
        XCTAssertEqual(loaded, exclusions)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }
}
