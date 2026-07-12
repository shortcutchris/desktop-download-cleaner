import DesktopCleanerServices
import XCTest

final class KeychainStoreTests: XCTestCase {
    func testSaveLoadAndDeleteRoundTrip() async throws {
        let store = KeychainStore(
            service: "com.desktopcleaner.tests.\(UUID().uuidString)",
            account: "temporary-test-key"
        )
        let dummyKey = "sk-" + String(repeating: "x", count: 32)

        try await store.saveAPIKey(dummyKey)
        let loaded = try await store.loadAPIKey()
        XCTAssertEqual(loaded, dummyKey)
        try await store.deleteAPIKey()
        let deleted = try await store.loadAPIKey()
        XCTAssertNil(deleted)
    }

    func testRejectsMalformedKey() async {
        let store = KeychainStore(service: "com.desktopcleaner.tests.invalid.\(UUID())")

        do {
            try await store.saveAPIKey("not-a-key")
            XCTFail("Expected invalid key")
        } catch {
            XCTAssertEqual(error as? KeychainStoreError, .invalidKey)
        }
    }
}
