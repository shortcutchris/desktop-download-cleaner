import DesktopCleanerCore
import Foundation

public enum RuleStoreError: Error {
    case invalidRuleFile
}

public actor RuleStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultURL()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func load() throws -> [UserRule] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try decoder.decode([UserRule].self, from: Data(contentsOf: fileURL))
    }

    public func save(_ rules: [UserRule]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(rules).write(to: fileURL, options: .atomic)
    }

    public func export(_ rules: [UserRule], to destination: URL) throws {
        try encoder.encode(rules).write(to: destination, options: .atomic)
    }

    public func importRules(from source: URL) throws -> [UserRule] {
        let rules = try decoder.decode([UserRule].self, from: Data(contentsOf: source))
        guard rules.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.condition.pattern.isEmpty }) else {
            throw RuleStoreError.invalidRuleFile
        }
        return rules
    }

    private static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("DesktopCleaner/rules.json")
    }
}
