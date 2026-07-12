import DesktopCleanerCore
import Foundation

public enum TransactionError: Error, Equatable {
    case noApprovedItems
    case missingSourceRoot
    case unsafeSourcePath
    case unsafeDestinationPath
    case sourceMissing
    case sourceChanged
    case rollbackPathOccupied
    case destinationUnavailable
    case invalidTransactionState
}

extension TransactionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noApprovedItems: "No approved items are ready to stage."
        case .missingSourceRoot: "The source folder is no longer authorized."
        case .unsafeSourcePath: "A source path failed the safety check."
        case .unsafeDestinationPath: "A destination path would leave the review folder."
        case .sourceMissing: "A source file disappeared after the scan."
        case .sourceChanged: "A source file changed after the scan. Scan again before staging."
        case .rollbackPathOccupied: "An original path is occupied. Nothing was overwritten; move the occupant and retry undo."
        case .destinationUnavailable: "A destination became occupied. Nothing was overwritten."
        case .invalidTransactionState: "This session cannot perform that action in its current state."
        }
    }
}

public actor TransactionExecutor {
    private let journalStore: TransactionJournalStore
    private let sanitizer: FilenameSanitizer

    public init(
        journalStore: TransactionJournalStore = TransactionJournalStore(),
        sanitizer: FilenameSanitizer = FilenameSanitizer()
    ) {
        self.journalStore = journalStore
        self.sanitizer = sanitizer
    }

    public func stage(
        plan: CleanupPlan,
        sourceRoots: [UUID: URL],
        reviewRoot: URL,
        operation: FileOperation
    ) async throws -> TransactionJournal {
        let approved = plan.items.filter { $0.approvalState == .approved }
        guard !approved.isEmpty else { throw TransactionError.noApprovedItems }

        var journal = TransactionJournal(planID: plan.id, state: .preflighting, reviewRootPath: reviewRoot.path)
        try await journalStore.persist(journal)

        do {
            journal.steps = try approved.map { item in
                guard let sourceRoot = sourceRoots[item.scannedItem.sourceID] else {
                    throw TransactionError.missingSourceRoot
                }
                let sourceURL = try containedURL(relativePath: item.scannedItem.relativePath, root: sourceRoot, error: .unsafeSourcePath)
                guard FileManager.default.fileExists(atPath: sourceURL.path) else { throw TransactionError.sourceMissing }
                guard try currentIdentity(for: sourceURL) == item.scannedItem.identity else { throw TransactionError.sourceChanged }
                let proposedURL = try containedURL(relativePath: item.relativeDestination, root: reviewRoot, error: .unsafeDestinationPath)
                let destinationURL = collisionSafeURL(for: proposedURL)
                return TransactionStep(
                    planItemID: item.id,
                    sourcePath: sourceURL.path,
                    destinationPath: destinationURL.path,
                    operation: operation
                )
            }

            journal.state = .applying
            journal.updatedAt = Date()
            try await journalStore.persist(journal)

            for index in journal.steps.indices {
                let sourceURL = URL(fileURLWithPath: journal.steps[index].sourcePath)
                let destinationURL = URL(fileURLWithPath: journal.steps[index].destinationPath)
                try FileManager.default.createDirectory(
                    at: destinationURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                guard !FileManager.default.fileExists(atPath: destinationURL.path) else {
                    throw TransactionError.destinationUnavailable
                }
                switch operation {
                case .move: try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
                case .copy: try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                }
                journal.steps[index].state = .applied
                journal.steps[index].completedAt = Date()
                journal.updatedAt = Date()
                try await journalStore.persist(journal)
            }

            journal.state = .staged
            journal.updatedAt = Date()
            try await journalStore.persist(journal)
            return journal
        } catch {
            journal.state = .failed
            journal.failureDescription = String(describing: error)
            journal.updatedAt = Date()
            try? await journalStore.persist(journal)
            throw error
        }
    }

    public func rollback(journalID: UUID) async throws -> TransactionJournal {
        var journal = try await journalStore.load(id: journalID)
        guard [.staged, .failed, .applying, .rollingBack].contains(journal.state) else {
            throw TransactionError.invalidTransactionState
        }
        journal.state = .rollingBack
        journal.updatedAt = Date()
        try await journalStore.persist(journal)

        do {
            let reviewRoot = URL(fileURLWithPath: journal.reviewRootPath, isDirectory: true).standardizedFileURL
            for index in journal.steps.indices.reversed() where journal.steps[index].state == .applied {
                let step = journal.steps[index]
                let destinationURL = URL(fileURLWithPath: step.destinationPath).standardizedFileURL
                guard Self.isContained(destinationURL, beneath: reviewRoot) else {
                    throw TransactionError.unsafeDestinationPath
                }
                let sourceURL = URL(fileURLWithPath: step.sourcePath)
                switch step.operation {
                case .move:
                    guard !FileManager.default.fileExists(atPath: sourceURL.path) else {
                        throw TransactionError.rollbackPathOccupied
                    }
                    try FileManager.default.createDirectory(
                        at: sourceURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    try FileManager.default.moveItem(at: destinationURL, to: sourceURL)
                case .copy:
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                }
                journal.steps[index].state = .rolledBack
                journal.updatedAt = Date()
                try await journalStore.persist(journal)
            }
            journal.state = .rolledBack
            journal.failureDescription = nil
            journal.updatedAt = Date()
            try await journalStore.persist(journal)
            return journal
        } catch {
            journal.state = .failed
            journal.failureDescription = String(describing: error)
            journal.updatedAt = Date()
            try? await journalStore.persist(journal)
            throw error
        }
    }

    public func recoverableJournals() async throws -> [TransactionJournal] {
        try await journalStore.loadAll().filter { [.applying, .rollingBack, .failed].contains($0.state) }
    }

    public func retain(journalID: UUID) async throws -> TransactionJournal {
        var journal = try await journalStore.load(id: journalID)
        guard journal.state == .staged else { throw TransactionError.invalidTransactionState }
        journal.state = .retained
        journal.updatedAt = Date()
        try await journalStore.persist(journal)
        return journal
    }

    private func containedURL(
        relativePath: String,
        root: URL,
        error: TransactionError
    ) throws -> URL {
        guard !relativePath.hasPrefix("/"), !relativePath.split(separator: "/").contains("..") else { throw error }
        let standardizedRoot = root.standardizedFileURL
        let result = standardizedRoot.appendingPathComponent(relativePath).standardizedFileURL
        guard Self.isContained(result, beneath: standardizedRoot) else { throw error }
        return result
    }

    private static func isContained(_ candidate: URL, beneath root: URL) -> Bool {
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        return candidate.path.hasPrefix(rootPath)
    }

    private func collisionSafeURL(for proposedURL: URL) -> URL {
        guard FileManager.default.fileExists(atPath: proposedURL.path) else { return proposedURL }
        var ordinal = 2
        while true {
            let filename = sanitizer.collisionFilename(original: proposedURL.lastPathComponent, ordinal: ordinal)
            let candidate = proposedURL.deletingLastPathComponent().appendingPathComponent(filename)
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            ordinal += 1
        }
    }

    private func currentIdentity(for url: URL) throws -> String {
        let values = try url.resourceValues(forKeys: [
            .fileResourceIdentifierKey, .fileSizeKey, .contentModificationDateKey
        ])
        let identifier = values.fileResourceIdentifier.map(String.init(describing:)) ?? "unavailable"
        return "\(identifier)|\(values.fileSize ?? 0)|\(values.contentModificationDate?.timeIntervalSince1970 ?? 0)"
    }
}
