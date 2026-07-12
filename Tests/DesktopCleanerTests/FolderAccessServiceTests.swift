import DesktopCleanerCore
import DesktopCleanerServices
import Foundation
import XCTest

final class FolderAccessServiceTests: XCTestCase {
    func testFolderAccessPersistsOnlyThroughServiceAndBalancesScopedAccess() async throws {
        let store = MemoryFolderStore()
        let codec = FakeBookmarkCodec()
        let service = FolderAccessService(store: store, codec: codec)
        let url = URL(fileURLWithPath: "/tmp/fixture-source", isDirectory: true)

        let folder = try await service.authorize(url, scanDepth: 2)
        let resolvedPath = try await service.withAccess(to: folder.id) { resolvedURL, source in
            XCTAssertEqual(source.scanDepth, 2)
            return resolvedURL.path
        }

        XCTAssertEqual(resolvedPath, url.path)
        XCTAssertEqual(codec.startCount, 1)
        XCTAssertEqual(codec.stopCount, 1)
        let authorizedFolders = try await service.authorizedFolders()
        XCTAssertEqual(authorizedFolders, [folder])
    }

    func testStaleBookmarkIsRejectedBeforeAccess() async throws {
        let store = MemoryFolderStore()
        let codec = FakeBookmarkCodec(isStale: true)
        let service = FolderAccessService(store: store, codec: codec)
        let folder = try await service.authorize(URL(fileURLWithPath: "/tmp/stale", isDirectory: true))

        do {
            _ = try await service.withAccess(to: folder.id) { url, _ in url }
            XCTFail("Expected stale bookmark error")
        } catch {
            XCTAssertEqual(error as? FolderAccessError, .staleBookmark)
        }
        XCTAssertEqual(codec.startCount, 0)
    }
}

private final class MemoryFolderStore: FolderAuthorizationStore, @unchecked Sendable {
    private let lock = NSLock()
    private var records: [StoredFolderAuthorization] = []

    func load() throws -> [StoredFolderAuthorization] {
        lock.withLock { records }
    }

    func save(_ authorizations: [StoredFolderAuthorization]) throws {
        lock.withLock { records = authorizations }
    }
}

private final class FakeBookmarkCodec: SecurityScopedBookmarkCodec, @unchecked Sendable {
    private let lock = NSLock()
    private let isStale: Bool
    private var starts = 0
    private var stops = 0

    init(isStale: Bool = false) {
        self.isStale = isStale
    }

    var startCount: Int { lock.withLock { starts } }
    var stopCount: Int { lock.withLock { stops } }

    func createBookmark(for url: URL) throws -> Data {
        Data(url.absoluteString.utf8)
    }

    func resolveBookmark(_ data: Data) throws -> (url: URL, isStale: Bool) {
        (URL(string: String(decoding: data, as: UTF8.self))!, isStale)
    }

    func startAccessing(_ url: URL) -> Bool {
        lock.withLock { starts += 1 }
        return true
    }

    func stopAccessing(_ url: URL) {
        lock.withLock { stops += 1 }
    }
}
