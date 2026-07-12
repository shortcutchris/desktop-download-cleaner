import DesktopCleanerCore
import DesktopCleanerServices
import Foundation
import XCTest

final class TransactionIntegrationTests: XCTestCase {
    private var root: URL!
    private var sourceRoot: URL!
    private var reviewRoot: URL!
    private var journalRoot: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("DesktopCleanerTransaction-\(UUID())")
        sourceRoot = root.appendingPathComponent("Source")
        reviewRoot = root.appendingPathComponent("Review")
        journalRoot = root.appendingPathComponent("Journals")
        try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: reviewRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    func testMoveStagesAndFullyRollsBackWithAppendOnlyJournal() async throws {
        let sourceFile = sourceRoot.appendingPathComponent("report.pdf")
        try Data("report".utf8).write(to: sourceFile)
        let source = SourceFolder(displayName: "Source")
        var plan = try await LocalCleanupService().scanAndPlan(
            source: source,
            at: sourceRoot,
            sessionDirectoryName: "Session"
        )
        plan.items[0].approvalState = .approved
        let store = TransactionJournalStore(rootURL: journalRoot)
        let executor = TransactionExecutor(journalStore: store)

        let staged = try await executor.stage(
            plan: plan,
            sourceRoots: [source.id: sourceRoot],
            reviewRoot: reviewRoot,
            operation: .move
        )

        XCTAssertEqual(staged.state, .staged)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: staged.steps[0].destinationPath))
        let eventsBeforeRollback = try String(contentsOf: await store.eventLogURL(id: staged.id), encoding: .utf8)
            .split(separator: "\n")
        XCTAssertGreaterThanOrEqual(eventsBeforeRollback.count, 4)

        let rolledBack = try await executor.rollback(journalID: staged.id)

        XCTAssertEqual(rolledBack.state, .rolledBack)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: staged.steps[0].destinationPath))
        XCTAssertEqual(try Data(contentsOf: sourceFile), Data("report".utf8))
    }

    func testCopyRollbackRemovesOnlyCreatedCopy() async throws {
        let sourceFile = sourceRoot.appendingPathComponent("image.png")
        try Data("image".utf8).write(to: sourceFile)
        let source = SourceFolder(displayName: "Source")
        var plan = try await LocalCleanupService().scanAndPlan(source: source, at: sourceRoot, sessionDirectoryName: "Session")
        plan.items[0].approvalState = .approved
        let executor = TransactionExecutor(journalStore: TransactionJournalStore(rootURL: journalRoot))

        let staged = try await executor.stage(
            plan: plan,
            sourceRoots: [source.id: sourceRoot],
            reviewRoot: reviewRoot,
            operation: .copy
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: staged.steps[0].destinationPath))

        _ = try await executor.rollback(journalID: staged.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: staged.steps[0].destinationPath))
    }

    func testStageResolvesLateDestinationCollisionWithoutOverwrite() async throws {
        let sourceFile = sourceRoot.appendingPathComponent("report.pdf")
        try Data("new".utf8).write(to: sourceFile)
        let existingDirectory = reviewRoot.appendingPathComponent("Session/Documents")
        try FileManager.default.createDirectory(at: existingDirectory, withIntermediateDirectories: true)
        let existingFile = existingDirectory.appendingPathComponent("report.pdf")
        try Data("existing".utf8).write(to: existingFile)
        let source = SourceFolder(displayName: "Source")
        var plan = try await LocalCleanupService().scanAndPlan(source: source, at: sourceRoot, sessionDirectoryName: "Session")
        plan.items[0].approvalState = .approved

        let staged = try await TransactionExecutor(journalStore: TransactionJournalStore(rootURL: journalRoot)).stage(
            plan: plan,
            sourceRoots: [source.id: sourceRoot],
            reviewRoot: reviewRoot,
            operation: .move
        )

        XCTAssertEqual(try Data(contentsOf: existingFile), Data("existing".utf8))
        XCTAssertTrue(staged.steps[0].destinationPath.hasSuffix("report – 2.pdf"))
    }

    func testRollbackStopsWhenOriginalPathIsOccupied() async throws {
        let sourceFile = sourceRoot.appendingPathComponent("report.pdf")
        try Data("original".utf8).write(to: sourceFile)
        let source = SourceFolder(displayName: "Source")
        var plan = try await LocalCleanupService().scanAndPlan(source: source, at: sourceRoot, sessionDirectoryName: "Session")
        plan.items[0].approvalState = .approved
        let executor = TransactionExecutor(journalStore: TransactionJournalStore(rootURL: journalRoot))
        let staged = try await executor.stage(
            plan: plan,
            sourceRoots: [source.id: sourceRoot],
            reviewRoot: reviewRoot,
            operation: .move
        )
        try Data("occupant".utf8).write(to: sourceFile)

        do {
            _ = try await executor.rollback(journalID: staged.id)
            XCTFail("Expected occupied rollback path")
        } catch {
            XCTAssertEqual(error as? TransactionError, .rollbackPathOccupied)
        }
        XCTAssertEqual(try Data(contentsOf: sourceFile), Data("occupant".utf8))
        XCTAssertTrue(FileManager.default.fileExists(atPath: staged.steps[0].destinationPath))
    }

    func testPartialFailureIsDiscoverableAndRecoverableAfterRelaunch() async throws {
        try Data("document".utf8).write(to: sourceRoot.appendingPathComponent("a.pdf"))
        try Data("archive".utf8).write(to: sourceRoot.appendingPathComponent("z.zip"))
        let source = SourceFolder(displayName: "Source")
        var plan = try await LocalCleanupService().scanAndPlan(source: source, at: sourceRoot, sessionDirectoryName: "Session")
        for index in plan.items.indices { plan.items[index].approvalState = .approved }
        let blockedArchiveDirectory = reviewRoot.appendingPathComponent("Session/Archives")
        try FileManager.default.createDirectory(at: blockedArchiveDirectory.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("occupant".utf8).write(to: blockedArchiveDirectory)
        let store = TransactionJournalStore(rootURL: journalRoot)
        let executor = TransactionExecutor(journalStore: store)

        do {
            _ = try await executor.stage(
                plan: plan,
                sourceRoots: [source.id: sourceRoot],
                reviewRoot: reviewRoot,
                operation: .move
            )
            XCTFail("Expected partial transaction failure")
        } catch {
            // The durable journal is the recovery authority.
        }

        let recoverable = try await TransactionExecutor(journalStore: store).recoverableJournals()
        let journal = try XCTUnwrap(recoverable.first)
        XCTAssertEqual(journal.state, .failed)
        XCTAssertEqual(journal.steps.filter { $0.state == .applied }.count, 1)

        let rolledBack = try await TransactionExecutor(journalStore: store).rollback(journalID: journal.id)
        XCTAssertEqual(rolledBack.state, .rolledBack)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceRoot.appendingPathComponent("a.pdf").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceRoot.appendingPathComponent("z.zip").path))
    }
}
