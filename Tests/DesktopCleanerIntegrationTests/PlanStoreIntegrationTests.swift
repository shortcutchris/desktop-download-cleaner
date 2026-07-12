import DesktopCleanerCore
import DesktopCleanerServices
import Foundation
import XCTest

final class PlanStoreIntegrationTests: XCTestCase {
    func testPlanRoundTripPersistsUserDecisionAndCanBeCleared() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopCleanerPlan-\(UUID())", isDirectory: true)
        let fileURL = root.appendingPathComponent("current-plan.json")
        let store = PlanStore(fileURL: fileURL)
        let scanned = ScannedItem(
            sourceID: UUID(),
            relativePath: "report.pdf",
            filename: "report.pdf",
            pathExtension: "pdf",
            identity: "identity"
        )
        let item = PlanItem(
            scannedItem: scanned,
            classification: Classification(category: .documents, confidence: .high, reason: "test"),
            proposedFilename: "Quarterly report.pdf",
            relativeDestination: "Session/Documents/Quarterly report.pdf",
            hadCollision: false,
            approvalState: .approved
        )
        let plan = CleanupPlan(sessionDirectoryName: "Session", items: [item])
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }

        try await store.save(plan)
        let loaded = try await store.load()

        XCTAssertEqual(loaded?.id, plan.id)
        XCTAssertEqual(loaded?.items.first?.approvalState, .approved)
        XCTAssertEqual(loaded?.items.first?.proposedFilename, "Quarterly report.pdf")
        try await store.clear()
        let cleared = try await store.load()
        XCTAssertNil(cleared)
    }
}
