import DesktopCleanerCore
import Foundation

public struct StoredFolderAuthorization: Codable, Sendable {
    public let folder: SourceFolder
    public let bookmarkData: Data

    public init(folder: SourceFolder, bookmarkData: Data) {
        self.folder = folder
        self.bookmarkData = bookmarkData
    }
}

public protocol FolderAuthorizationStore: Sendable {
    func load() throws -> [StoredFolderAuthorization]
    func save(_ authorizations: [StoredFolderAuthorization]) throws
}

public protocol SecurityScopedBookmarkCodec: Sendable {
    func createBookmark(for url: URL) throws -> Data
    func resolveBookmark(_ data: Data) throws -> (url: URL, isStale: Bool)
    func startAccessing(_ url: URL) -> Bool
    func stopAccessing(_ url: URL)
}

public struct FoundationSecurityScopedBookmarkCodec: SecurityScopedBookmarkCodec {
    public init() {}

    public func createBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    public func resolveBookmark(_ data: Data) throws -> (url: URL, isStale: Bool) {
        var stale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        return (url, stale)
    }

    public func startAccessing(_ url: URL) -> Bool { url.startAccessingSecurityScopedResource() }
    public func stopAccessing(_ url: URL) { url.stopAccessingSecurityScopedResource() }
}

public final class UserDefaultsFolderAuthorizationStore: FolderAuthorizationStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "authorizedSourceFolders") {
        self.defaults = defaults
        self.key = key
    }

    public func load() throws -> [StoredFolderAuthorization] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return try PropertyListDecoder().decode([StoredFolderAuthorization].self, from: data)
    }

    public func save(_ authorizations: [StoredFolderAuthorization]) throws {
        defaults.set(try PropertyListEncoder().encode(authorizations), forKey: key)
    }
}

public enum FolderAccessError: Error, Equatable {
    case authorizationNotFound
    case staleBookmark
    case accessDenied
}

extension FolderAccessError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .authorizationNotFound: "Folder access is missing. Choose the folder again."
        case .staleBookmark: "Folder access expired. Choose the folder again."
        case .accessDenied: "macOS denied access to this folder."
        }
    }
}

public final class FolderAccessSession: @unchecked Sendable {
    public let url: URL
    public let folder: SourceFolder
    private let codec: any SecurityScopedBookmarkCodec

    fileprivate init(url: URL, folder: SourceFolder, codec: any SecurityScopedBookmarkCodec) {
        self.url = url
        self.folder = folder
        self.codec = codec
    }

    deinit {
        codec.stopAccessing(url)
    }
}

public actor FolderAccessService {
    private let store: any FolderAuthorizationStore
    private let codec: any SecurityScopedBookmarkCodec

    public init(
        store: any FolderAuthorizationStore = UserDefaultsFolderAuthorizationStore(),
        codec: any SecurityScopedBookmarkCodec = FoundationSecurityScopedBookmarkCodec()
    ) {
        self.store = store
        self.codec = codec
    }

    public func authorize(
        _ url: URL,
        scanDepth: Int = 0,
        kind: SourceFolderKind = .source
    ) throws -> SourceFolder {
        let folder = SourceFolder(displayName: url.lastPathComponent, scanDepth: scanDepth, kind: kind)
        let bookmarkData = try codec.createBookmark(for: url)
        var records = try store.load()
        records.removeAll { $0.folder.id == folder.id }
        records.append(StoredFolderAuthorization(folder: folder, bookmarkData: bookmarkData))
        try store.save(records)
        return folder
    }

    public func authorizedFolders() throws -> [SourceFolder] {
        try store.load().map(\.folder)
    }

    public func removeAuthorization(for id: UUID) throws {
        var records = try store.load()
        records.removeAll { $0.folder.id == id }
        try store.save(records)
    }

    public func withAccess<T: Sendable>(
        to id: UUID,
        operation: @Sendable (URL, SourceFolder) async throws -> T
    ) async throws -> T {
        guard let record = try store.load().first(where: { $0.folder.id == id }) else {
            throw FolderAccessError.authorizationNotFound
        }
        let resolution = try codec.resolveBookmark(record.bookmarkData)
        guard !resolution.isStale else { throw FolderAccessError.staleBookmark }
        guard codec.startAccessing(resolution.url) else { throw FolderAccessError.accessDenied }
        defer { codec.stopAccessing(resolution.url) }
        return try await operation(resolution.url, record.folder)
    }

    public func beginAccess(to id: UUID) throws -> FolderAccessSession {
        guard let record = try store.load().first(where: { $0.folder.id == id }) else {
            throw FolderAccessError.authorizationNotFound
        }
        let resolution = try codec.resolveBookmark(record.bookmarkData)
        guard !resolution.isStale else { throw FolderAccessError.staleBookmark }
        guard codec.startAccessing(resolution.url) else { throw FolderAccessError.accessDenied }
        return FolderAccessSession(url: resolution.url, folder: record.folder, codec: codec)
    }
}
