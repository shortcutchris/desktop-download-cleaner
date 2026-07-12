import Foundation

public enum ExclusionRuleKind: String, Codable, Sendable {
    case filename
    case pathExtension
    case relativePath
}

public struct ExclusionRule: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let kind: ExclusionRuleKind
    public let pattern: String

    public init(id: UUID = UUID(), kind: ExclusionRuleKind, pattern: String) {
        self.id = id
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

public enum GlobMatcher {
    public static func matches(pattern: String, candidate: String) -> Bool {
        let pattern = Array(pattern.lowercased())
        let candidate = Array(candidate.lowercased())
        var memo: [MatchPosition: Bool] = [:]

        func match(_ patternIndex: Int, _ candidateIndex: Int) -> Bool {
            let position = MatchPosition(pattern: patternIndex, candidate: candidateIndex)
            if let cached = memo[position] { return cached }

            let result: Bool
            if patternIndex == pattern.count {
                result = candidateIndex == candidate.count
            } else if pattern[patternIndex] == "*" {
                result = match(patternIndex + 1, candidateIndex)
                    || (candidateIndex < candidate.count && match(patternIndex, candidateIndex + 1))
            } else if pattern[patternIndex] == "?" {
                result = candidateIndex < candidate.count
                    && match(patternIndex + 1, candidateIndex + 1)
            } else {
                result = candidateIndex < candidate.count
                    && pattern[patternIndex] == candidate[candidateIndex]
                    && match(patternIndex + 1, candidateIndex + 1)
            }
            memo[position] = result
            return result
        }

        return match(0, 0)
    }

    private struct MatchPosition: Hashable {
        let pattern: Int
        let candidate: Int
    }
}
