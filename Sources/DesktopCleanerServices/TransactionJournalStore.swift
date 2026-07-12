import DesktopCleanerCore
import Foundation

public enum JournalStoreError: Error {
    case journalNotFound
}

public actor TransactionJournalStore {
    private let rootURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(rootURL: URL? = nil) {
        self.rootURL = rootURL ?? Self.defaultRootURL()
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func persist(_ journal: TransactionJournal) throws {
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let snapshotURL = rootURL.appendingPathComponent("\(journal.id.uuidString).json")
        try encoder.encode(journal).write(to: snapshotURL, options: .atomic)
        try appendEvent(for: journal)
    }

    public func load(id: UUID) throws -> TransactionJournal {
        let url = rootURL.appendingPathComponent("\(id.uuidString).json")
        guard FileManager.default.fileExists(atPath: url.path) else { throw JournalStoreError.journalNotFound }
        return try decoder.decode(TransactionJournal.self, from: Data(contentsOf: url))
    }

    public func loadAll() throws -> [TransactionJournal] {
        guard FileManager.default.fileExists(atPath: rootURL.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "json" }
        .compactMap { try? decoder.decode(TransactionJournal.self, from: Data(contentsOf: $0)) }
        .sorted { $0.createdAt > $1.createdAt }
    }

    public func eventLogURL(id: UUID) -> URL {
        rootURL.appendingPathComponent("\(id.uuidString).jsonl")
    }

    public func removeFinalized(ids: [UUID]) throws {
        for id in ids {
            let journal = try? load(id: id)
            guard let journal, [.retained, .rolledBack].contains(journal.state) else { continue }
            let snapshotURL = rootURL.appendingPathComponent("\(id.uuidString).json")
            let eventsURL = eventLogURL(id: id)
            if FileManager.default.fileExists(atPath: snapshotURL.path) {
                try FileManager.default.removeItem(at: snapshotURL)
            }
            if FileManager.default.fileExists(atPath: eventsURL.path) {
                try FileManager.default.removeItem(at: eventsURL)
            }
        }
    }

    private func appendEvent(for journal: TransactionJournal) throws {
        let event = JournalEvent(
            timestamp: journal.updatedAt,
            state: journal.state,
            appliedStepCount: journal.steps.filter { $0.state == .applied }.count,
            failureDescription: journal.failureDescription
        )
        let eventEncoder = JSONEncoder()
        eventEncoder.outputFormatting = [.sortedKeys]
        eventEncoder.dateEncodingStrategy = .iso8601
        var data = try eventEncoder.encode(event)
        data.append(0x0A)
        let url = eventLogURL(id: journal.id)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.synchronize()
    }

    private static func defaultRootURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("DesktopCleaner/TransactionJournals", isDirectory: true)
    }

    private struct JournalEvent: Codable {
        let timestamp: Date
        let state: TransactionState
        let appliedStepCount: Int
        let failureDescription: String?
    }
}
