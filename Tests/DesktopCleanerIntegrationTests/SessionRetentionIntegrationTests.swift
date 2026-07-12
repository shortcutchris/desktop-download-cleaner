import DesktopCleanerCore
import DesktopCleanerServices
import Foundation
import XCTest

final class SessionRetentionIntegrationTests: XCTestCase {
    func testPruneRemovesOnlyOldFinalizedMetadataAndJournals() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopCleanerRetention-\(UUID())", isDirectory: true)
        let sessionStore = SessionStore(fileURL: root.appendingPathComponent("sessions.json"))
        let journalStore = TransactionJournalStore(rootURL: root.appendingPathComponent("journals"))
        let oldDate = Date(timeIntervalSince1970: 1_000)
        let cutoff = Date(timeIntervalSince1970: 2_000)
        let oldRetainedJournal = TransactionJournal(
            planID: UUID(),
            createdAt: oldDate,
            updatedAt: oldDate,
            state: .retained,
            reviewRootPath: root.path
        )
        let oldStagedJournal = TransactionJournal(
            planID: UUID(),
            createdAt: oldDate,
            updatedAt: oldDate,
            state: .staged,
            reviewRootPath: root.path
        )
        try await journalStore.persist(oldRetainedJournal)
        try await journalStore.persist(oldStagedJournal)
        try await sessionStore.upsert(CleanupSession(
            planID: oldRetainedJournal.planID,
            journalID: oldRetainedJournal.id,
            sessionDirectoryName: "Old retained",
            createdAt: oldDate,
            state: .retained,
            itemCount: 0
        ))
        try await sessionStore.upsert(CleanupSession(
            planID: oldStagedJournal.planID,
            journalID: oldStagedJournal.id,
            sessionDirectoryName: "Old staged",
            createdAt: oldDate,
            state: .staged,
            itemCount: 0
        ))
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }

        let removedIDs = try await sessionStore.pruneFinalized(before: cutoff)
        try await journalStore.removeFinalized(ids: removedIDs)
        let remainingSessions = try await sessionStore.load()

        XCTAssertEqual(removedIDs, [oldRetainedJournal.id])
        XCTAssertEqual(remainingSessions.map(\.journalID), [oldStagedJournal.id])
        do {
            _ = try await journalStore.load(id: oldRetainedJournal.id)
            XCTFail("Expected retained journal metadata to be pruned")
        } catch {
            XCTAssertTrue(error is JournalStoreError)
        }
        let remainingJournal = try await journalStore.load(id: oldStagedJournal.id)
        XCTAssertEqual(remainingJournal.state, TransactionState.staged)
    }
}
