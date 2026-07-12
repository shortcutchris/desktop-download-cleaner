import DesktopCleanerCore
import XCTest

final class PlanningEngineTests: XCTestCase {
    func testBuildsOnlyRelativeAllowlistedCategoryDestinations() {
        let item = makeItem(filename: "report.pdf", typeIdentifier: "com.adobe.pdf")
        let classification = ClassificationEngine().classify(item)

        let plan = PlanningEngine().makePlan(
            items: [item],
            classifications: [item.id: classification],
            sessionDirectoryName: "2026-07-12 14-30"
        )

        XCTAssertEqual(plan.items.first?.relativeDestination, "2026-07-12 14-30/Documents/report.pdf")
        XCTAssertFalse(plan.items.first!.relativeDestination.hasPrefix("/"))
        XCTAssertFalse(plan.items.first!.relativeDestination.split(separator: "/").contains(".."))
    }

    func testCollisionHandlingIsCaseInsensitiveAndNeverOverwrites() {
        let first = makeItem(filename: "Report.pdf", typeIdentifier: "com.adobe.pdf", relativePath: "a/Report.pdf")
        let second = makeItem(filename: "report.pdf", typeIdentifier: "com.adobe.pdf", relativePath: "b/report.pdf")
        let classification = Classification(category: .documents, confidence: .high, reason: "Test")

        let plan = PlanningEngine().makePlan(
            items: [first, second],
            classifications: [first.id: classification, second.id: classification],
            sessionDirectoryName: "Session"
        )

        XCTAssertEqual(plan.items.map(\.proposedFilename), ["Report.pdf", "report – 2.pdf"])
        XCTAssertEqual(plan.items.map(\.hadCollision), [false, true])
    }

    func testExistingDestinationAlsoGetsCollisionSuffix() {
        let item = makeItem(filename: "report.pdf", typeIdentifier: "com.adobe.pdf")
        let classification = Classification(category: .documents, confidence: .high, reason: "Test")

        let plan = PlanningEngine().makePlan(
            items: [item],
            classifications: [item.id: classification],
            sessionDirectoryName: "Session",
            existingRelativeDestinations: ["Session/Documents/report.pdf"]
        )

        XCTAssertEqual(plan.items.first?.proposedFilename, "report – 2.pdf")
        XCTAssertTrue(plan.items.first?.hadCollision == true)
    }

    func testExcludedItemsDoNotEnterPlan() {
        let item = makeItem(filename: "ignored.tmp")
        let classification = Classification(
            category: .unclear,
            confidence: .high,
            reason: "Excluded",
            isExcluded: true
        )

        let plan = PlanningEngine().makePlan(
            items: [item],
            classifications: [item.id: classification],
            sessionDirectoryName: "Session"
        )

        XCTAssertTrue(plan.items.isEmpty)
    }
}

