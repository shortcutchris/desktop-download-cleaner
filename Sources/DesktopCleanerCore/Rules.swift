import Foundation

public enum RuleConditionKind: String, Codable, Sendable {
    case filename
    case pathExtension
    case relativePath
}

public struct RuleCondition: Codable, Hashable, Sendable {
    public var kind: RuleConditionKind
    public var pattern: String

    public init(kind: RuleConditionKind, pattern: String) {
        self.kind = kind
        self.pattern = pattern
    }

    public func matches(_ item: ScannedItem) -> Bool {
        let candidate = switch kind {
        case .filename: item.filename
        case .pathExtension: item.pathExtension
        case .relativePath: item.relativePath
        }
        return GlobMatcher.matches(pattern: pattern, candidate: candidate)
    }
}

public struct UserRule: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var isEnabled: Bool
    public var order: Int
    public var condition: RuleCondition
    public var category: ItemCategory
    public var basenameTemplate: String?

    public init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool = true,
        order: Int,
        condition: RuleCondition,
        category: ItemCategory,
        basenameTemplate: String? = nil
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.order = order
        self.condition = condition
        self.category = category
        self.basenameTemplate = basenameTemplate
    }
}

public struct RuleConflict: Equatable, Sendable {
    public let firstRuleID: UUID
    public let secondRuleID: UUID
    public let reason: String

    public init(firstRuleID: UUID, secondRuleID: UUID, reason: String) {
        self.firstRuleID = firstRuleID
        self.secondRuleID = secondRuleID
        self.reason = reason
    }
}

public struct RuleEvaluation: Equatable, Sendable {
    public let ruleID: UUID
    public let classification: Classification
    public let suggestedBasename: String?
}

public struct RuleEngine: Sendable {
    private let rules: [UserRule]

    public init(rules: [UserRule]) {
        self.rules = rules.sorted { ($0.order, $0.name) < ($1.order, $1.name) }
    }

    public func evaluate(_ item: ScannedItem) -> RuleEvaluation? {
        guard let rule = rules.first(where: { $0.isEnabled && $0.condition.matches(item) }) else { return nil }
        return RuleEvaluation(
            ruleID: rule.id,
            classification: Classification(
                category: rule.category,
                confidence: .high,
                reason: "Matched user rule: \(rule.name)"
            ),
            suggestedBasename: rule.basenameTemplate.map { render(template: $0, item: item) }
        )
    }

    public func conflicts() -> [RuleConflict] {
        let enabled = rules.filter(\.isEnabled)
        var conflicts: [RuleConflict] = []
        for firstIndex in enabled.indices {
            for secondIndex in enabled.indices where secondIndex > firstIndex {
                let first = enabled[firstIndex]
                let second = enabled[secondIndex]
                if first.condition == second.condition,
                   first.category != second.category || first.basenameTemplate != second.basenameTemplate {
                    conflicts.append(RuleConflict(
                        firstRuleID: first.id,
                        secondRuleID: second.id,
                        reason: "Identical conditions produce different outcomes"
                    ))
                }
            }
        }
        return conflicts
    }

    private func render(template: String, item: ScannedItem) -> String {
        template
            .replacingOccurrences(of: "{basename}", with: item.basename)
            .replacingOccurrences(of: "{extension}", with: item.pathExtension)
    }
}
