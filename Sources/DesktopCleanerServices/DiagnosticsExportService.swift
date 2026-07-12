import DesktopCleanerCore
import Foundation

public struct DiagnosticsInput: Sendable {
    public let appVersion: String
    public let buildNumber: String
    public let sourceCount: Int
    public let sessionStateCounts: [String: Int]
    public let ruleCount: Int
    public let exclusionCount: Int
    public let hasAPIKey: Bool
    public let aiPrivacyLevel: String
    public let aiQuality: AIQualityPreference
    public let operation: FileOperation
    public let minimumAgeDays: Int
    public let menuBarEnabled: Bool
    public let renamePreferences: RenamePreferences
    public let sessionRetention: SessionHistoryRetention

    public init(
        appVersion: String,
        buildNumber: String,
        sourceCount: Int,
        sessionStateCounts: [String: Int],
        ruleCount: Int,
        exclusionCount: Int,
        hasAPIKey: Bool,
        aiPrivacyLevel: String,
        aiQuality: AIQualityPreference,
        operation: FileOperation,
        minimumAgeDays: Int,
        menuBarEnabled: Bool,
        renamePreferences: RenamePreferences,
        sessionRetention: SessionHistoryRetention
    ) {
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.sourceCount = sourceCount
        self.sessionStateCounts = sessionStateCounts
        self.ruleCount = ruleCount
        self.exclusionCount = exclusionCount
        self.hasAPIKey = hasAPIKey
        self.aiPrivacyLevel = aiPrivacyLevel
        self.aiQuality = aiQuality
        self.operation = operation
        self.minimumAgeDays = minimumAgeDays
        self.menuBarEnabled = menuBarEnabled
        self.renamePreferences = renamePreferences
        self.sessionRetention = sessionRetention
    }
}

public struct DiagnosticsExportService: Sendable {
    public init() {}

    public func reportData(for input: DiagnosticsInput, generatedAt: Date = Date()) throws -> Data {
        let report = DiagnosticsReport(
            generatedAt: generatedAt,
            appVersion: input.appVersion,
            buildNumber: input.buildNumber,
            operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
            sourceCount: input.sourceCount,
            sessionStateCounts: input.sessionStateCounts,
            ruleCount: input.ruleCount,
            exclusionCount: input.exclusionCount,
            apiKeyStored: input.hasAPIKey,
            aiPrivacyLevel: input.aiPrivacyLevel,
            aiQuality: input.aiQuality.rawValue,
            operation: input.operation.rawValue,
            minimumAgeDays: input.minimumAgeDays,
            menuBarEnabled: input.menuBarEnabled,
            namingStyle: input.renamePreferences.namingStyle.rawValue,
            dateStyle: input.renamePreferences.dateStyle.rawValue,
            collisionSuffixStyle: input.renamePreferences.collisionSuffixStyle.rawValue,
            sessionRetention: input.sessionRetention.rawValue,
            privateFileDataIncluded: false,
            apiKeyValueIncluded: false
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(report)
    }

    public func preview(for input: DiagnosticsInput) throws -> String {
        String(decoding: try reportData(for: input), as: UTF8.self)
    }

    public func export(_ data: Data, to destination: URL) throws {
        try data.write(to: destination, options: .atomic)
    }

    private struct DiagnosticsReport: Codable {
        let generatedAt: Date
        let appVersion: String
        let buildNumber: String
        let operatingSystem: String
        let sourceCount: Int
        let sessionStateCounts: [String: Int]
        let ruleCount: Int
        let exclusionCount: Int
        let apiKeyStored: Bool
        let aiPrivacyLevel: String
        let aiQuality: String
        let operation: String
        let minimumAgeDays: Int
        let menuBarEnabled: Bool
        let namingStyle: String
        let dateStyle: String
        let collisionSuffixStyle: String
        let sessionRetention: String
        let privateFileDataIncluded: Bool
        let apiKeyValueIncluded: Bool
    }
}
