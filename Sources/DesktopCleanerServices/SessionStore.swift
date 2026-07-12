import DesktopCleanerCore
import Foundation

public actor SessionStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultURL()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load() throws -> [CleanupSession] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try decoder.decode([CleanupSession].self, from: Data(contentsOf: fileURL))
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func upsert(_ session: CleanupSession) throws {
        var sessions = try load()
        sessions.removeAll { $0.id == session.id || $0.journalID == session.journalID }
        sessions.append(session)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(sessions).write(to: fileURL, options: .atomic)
    }

    public func updateState(journalID: UUID, state: TransactionState) throws {
        var sessions = try load()
        guard let index = sessions.firstIndex(where: { $0.journalID == journalID }) else { return }
        sessions[index].state = state
        try encoder.encode(sessions).write(to: fileURL, options: .atomic)
    }

    private static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("DesktopCleaner/sessions.json")
    }
}

