import Foundation

public enum FileOperation: String, Codable, Sendable {
    case move
    case copy
}

public enum TransactionState: String, Codable, Sendable {
    case draft
    case preflighting
    case applying
    case staged
    case failed
    case rollingBack
    case rolledBack
    case retained
}

public enum TransactionStepState: String, Codable, Sendable {
    case planned
    case applied
    case rolledBack
}

public struct TransactionStep: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let planItemID: UUID
    public let sourcePath: String
    public let destinationPath: String
    public let operation: FileOperation
    public var state: TransactionStepState
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        planItemID: UUID,
        sourcePath: String,
        destinationPath: String,
        operation: FileOperation,
        state: TransactionStepState = .planned,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.planItemID = planItemID
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.operation = operation
        self.state = state
        self.completedAt = completedAt
    }
}

public struct TransactionJournal: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let planID: UUID
    public let createdAt: Date
    public var updatedAt: Date
    public var state: TransactionState
    public let reviewRootPath: String
    public var steps: [TransactionStep]
    public var failureDescription: String?

    public init(
        id: UUID = UUID(),
        planID: UUID,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        state: TransactionState = .draft,
        reviewRootPath: String,
        steps: [TransactionStep] = [],
        failureDescription: String? = nil
    ) {
        self.id = id
        self.planID = planID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.state = state
        self.reviewRootPath = reviewRootPath
        self.steps = steps
        self.failureDescription = failureDescription
    }
}

public struct CleanupSession: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let planID: UUID
    public let journalID: UUID
    public let sessionDirectoryName: String
    public let createdAt: Date
    public var state: TransactionState
    public let itemCount: Int

    public init(
        id: UUID = UUID(),
        planID: UUID,
        journalID: UUID,
        sessionDirectoryName: String,
        createdAt: Date = Date(),
        state: TransactionState,
        itemCount: Int
    ) {
        self.id = id
        self.planID = planID
        self.journalID = journalID
        self.sessionDirectoryName = sessionDirectoryName
        self.createdAt = createdAt
        self.state = state
        self.itemCount = itemCount
    }
}

