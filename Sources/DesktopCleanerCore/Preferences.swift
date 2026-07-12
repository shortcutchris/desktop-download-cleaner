import Foundation

public enum FilenameNamingStyle: String, CaseIterable, Codable, Sendable {
    case natural
    case hyphenated
    case underscored

    public var displayName: String {
        switch self {
        case .natural: "Natural spaces"
        case .hyphenated: "Hyphenated"
        case .underscored: "Underscored"
        }
    }
}

public enum FilenameDateStyle: String, CaseIterable, Codable, Sendable {
    case preserve
    case iso8601

    public var displayName: String {
        switch self {
        case .preserve: "Preserve detected dates"
        case .iso8601: "Normalize as YYYY-MM-DD"
        }
    }
}

public enum CollisionSuffixStyle: String, CaseIterable, Codable, Sendable {
    case enDash
    case parentheses
    case hyphen

    public var displayName: String {
        switch self {
        case .enDash: "Name – 2"
        case .parentheses: "Name (2)"
        case .hyphen: "Name - 2"
        }
    }
}

public struct RenamePreferences: Codable, Equatable, Sendable {
    public var namingStyle: FilenameNamingStyle
    public var dateStyle: FilenameDateStyle
    public var collisionSuffixStyle: CollisionSuffixStyle

    public init(
        namingStyle: FilenameNamingStyle = .natural,
        dateStyle: FilenameDateStyle = .preserve,
        collisionSuffixStyle: CollisionSuffixStyle = .enDash
    ) {
        self.namingStyle = namingStyle
        self.dateStyle = dateStyle
        self.collisionSuffixStyle = collisionSuffixStyle
    }
}

public enum AIQualityPreference: String, CaseIterable, Codable, Sendable {
    case fast
    case balanced
    case thorough

    public var displayName: String {
        switch self {
        case .fast: "Fast"
        case .balanced: "Balanced"
        case .thorough: "Thorough"
        }
    }

    public var reasoningEffort: String {
        switch self {
        case .fast: "low"
        case .balanced: "medium"
        case .thorough: "high"
        }
    }
}

public enum SessionHistoryRetention: String, CaseIterable, Codable, Sendable {
    case forever
    case thirtyDays
    case ninetyDays

    public var displayName: String {
        switch self {
        case .forever: "Keep forever"
        case .thirtyDays: "Keep 30 days"
        case .ninetyDays: "Keep 90 days"
        }
    }

    public var dayCount: Int? {
        switch self {
        case .forever: nil
        case .thirtyDays: 30
        case .ninetyDays: 90
        }
    }
}
