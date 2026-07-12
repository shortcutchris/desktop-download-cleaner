import DesktopCleanerCore
import XCTest

final class AIProposalValidatorTests: XCTestCase {
    func testValidStructuredProposalIsAccepted() throws {
        let id = UUID()
        let raw = AIRawProposal(
            id: id.uuidString,
            category: ItemCategory.documents.rawValue,
            suggestedBasename: "Project proposal – July 2026",
            confidence: ClassificationConfidence.high.rawValue,
            reason: "Metadata identifies a proposal.",
            warnings: []
        )

        let result = try AIProposalValidator().validate([raw], expectedItemIDs: [id])

        XCTAssertEqual(result.first?.itemID, id)
        XCTAssertEqual(result.first?.suggestedBasename, "Project proposal – July 2026")
    }

    func testTraversalBasenameIsRejected() {
        let id = UUID()
        let raw = rawProposal(id: id, basename: "../../Outside")

        XCTAssertThrowsError(try AIProposalValidator().validate([raw], expectedItemIDs: [id])) {
            XCTAssertEqual($0 as? AIProposalValidationError, .unsafeBasename)
        }
    }

    func testUnknownAndDuplicateIDsAreRejected() throws {
        let expected = UUID()
        XCTAssertThrowsError(
            try AIProposalValidator().validate([rawProposal(id: UUID())], expectedItemIDs: [expected])
        ) {
            XCTAssertEqual($0 as? AIProposalValidationError, .unknownItemID)
        }

        let duplicate = rawProposal(id: expected)
        XCTAssertThrowsError(
            try AIProposalValidator().validate([duplicate, duplicate], expectedItemIDs: [expected])
        ) {
            XCTAssertEqual($0 as? AIProposalValidationError, .duplicateItemID)
        }
    }

    func testMissingItemIsRejected() {
        XCTAssertThrowsError(
            try AIProposalValidator().validate([], expectedItemIDs: [UUID()])
        ) {
            XCTAssertEqual($0 as? AIProposalValidationError, .missingItemID)
        }
    }

    func testRealExtensionIsRemovedBeforeProposalCrossesBoundary() throws {
        let item = makeItem(filename: "report.PDF")
        let raw = rawProposal(id: item.id, basename: "Quarterly Report.pdf")

        let result = try AIProposalValidator().validate([raw], expectedItems: [item.id: item])

        XCTAssertEqual(result.first?.suggestedBasename, "Quarterly Report")
    }

    private func rawProposal(id: UUID, basename: String = "Safe name") -> AIRawProposal {
        AIRawProposal(
            id: id.uuidString,
            category: ItemCategory.documents.rawValue,
            suggestedBasename: basename,
            confidence: ClassificationConfidence.medium.rawValue,
            reason: "Test reason",
            warnings: []
        )
    }
}
