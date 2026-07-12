import Foundation

public enum AIPrivacyLevel: String, CaseIterable, Codable, Sendable {
    case off
    case metadataOnly
    case textPreview
    case visualPreview
}

public struct AIProposal: Codable, Equatable, Sendable {
    public let itemID: UUID
    public let category: ItemCategory
    public let suggestedBasename: String
    public let confidence: ClassificationConfidence
    public let reason: String
    public let warnings: [String]

    public init(
        itemID: UUID,
        category: ItemCategory,
        suggestedBasename: String,
        confidence: ClassificationConfidence,
        reason: String,
        warnings: [String]
    ) {
        self.itemID = itemID
        self.category = category
        self.suggestedBasename = suggestedBasename
        self.confidence = confidence
        self.reason = reason
        self.warnings = warnings
    }
}

public struct AIRawProposal: Codable, Sendable {
    public let id: String
    public let category: String
    public let suggestedBasename: String
    public let confidence: String
    public let reason: String
    public let warnings: [String]

    public init(
        id: String,
        category: String,
        suggestedBasename: String,
        confidence: String,
        reason: String,
        warnings: [String]
    ) {
        self.id = id
        self.category = category
        self.suggestedBasename = suggestedBasename
        self.confidence = confidence
        self.reason = reason
        self.warnings = warnings
    }
}

public enum AIProposalValidationError: Error, Equatable {
    case duplicateItemID
    case unknownItemID
    case missingItemID
    case invalidCategory
    case invalidConfidence
    case unsafeBasename
    case invalidReason
    case tooManyWarnings
}

public struct AIProposalValidator: Sendable {
    public init() {}

    public func validate(_ raw: [AIRawProposal], expectedItemIDs: Set<UUID>) throws -> [AIProposal] {
        try validate(
            raw,
            expectedItemExtensions: Dictionary(uniqueKeysWithValues: expectedItemIDs.map { ($0, "") })
        )
    }

    public func validate(_ raw: [AIRawProposal], expectedItems: [UUID: ScannedItem]) throws -> [AIProposal] {
        try validate(raw, expectedItemExtensions: expectedItems.mapValues(\.pathExtension))
    }

    private func validate(_ raw: [AIRawProposal], expectedItemExtensions: [UUID: String]) throws -> [AIProposal] {
        let expectedItemIDs = Set(expectedItemExtensions.keys)
        var seen = Set<UUID>()
        var proposals: [AIProposal] = []
        for item in raw {
            guard let id = UUID(uuidString: item.id), expectedItemIDs.contains(id) else {
                throw AIProposalValidationError.unknownItemID
            }
            guard seen.insert(id).inserted else { throw AIProposalValidationError.duplicateItemID }
            guard let category = ItemCategory(rawValue: item.category) else {
                throw AIProposalValidationError.invalidCategory
            }
            guard let confidence = ClassificationConfidence(rawValue: item.confidence) else {
                throw AIProposalValidationError.invalidConfidence
            }
            let suggestedBasename = Self.removeRealExtension(
                from: item.suggestedBasename,
                pathExtension: expectedItemExtensions[id] ?? ""
            )
            guard Self.isSafeBasename(suggestedBasename) else {
                throw AIProposalValidationError.unsafeBasename
            }
            let reason = item.reason.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !reason.isEmpty, reason.count <= 500 else { throw AIProposalValidationError.invalidReason }
            guard item.warnings.count <= 10 else { throw AIProposalValidationError.tooManyWarnings }

            proposals.append(AIProposal(
                itemID: id,
                category: category,
                suggestedBasename: suggestedBasename,
                confidence: confidence,
                reason: reason,
                warnings: item.warnings
            ))
        }
        guard seen == expectedItemIDs else { throw AIProposalValidationError.missingItemID }
        return proposals
    }

    private static func removeRealExtension(from value: String, pathExtension: String) -> String {
        guard !pathExtension.isEmpty else { return value }
        let suffix = ".\(pathExtension)"
        guard value.lowercased().hasSuffix(suffix.lowercased()) else { return value }
        return String(value.dropLast(suffix.count))
    }

    private static func isSafeBasename(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != ".", trimmed != "..", trimmed.utf8.count <= 180 else { return false }
        return !trimmed.unicodeScalars.contains { scalar in
            scalar == "/" || scalar == ":" || scalar.value == 0 || CharacterSet.controlCharacters.contains(scalar)
        }
    }
}
