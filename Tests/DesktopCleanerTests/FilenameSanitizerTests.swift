import DesktopCleanerCore
import XCTest

final class FilenameSanitizerTests: XCTestCase {
    func testRemovesSeparatorsControlsAndNormalizesWhitespace() {
        let result = FilenameSanitizer().normalizedBasename("  Quarterly/Report:\n  2026  ")

        XCTAssertEqual(result, "QuarterlyReport 2026")
    }

    func testNeverRemovesOrChangesExtension() {
        let item = makeItem(filename: "  report (2)  .PDF")

        XCTAssertEqual(FilenameSanitizer().suggestedFilename(for: item), "report.PDF")
    }

    func testUsesSafeFallbackForReservedBasename() {
        XCTAssertEqual(FilenameSanitizer().normalizedBasename("../"), "Untitled")
    }

    func testAppliesConfiguredNamingDateAndCollisionStylesWithoutChangingExtension() {
        let sanitizer = FilenameSanitizer(preferences: RenamePreferences(
            namingStyle: .underscored,
            dateStyle: .iso8601,
            collisionSuffixStyle: .parentheses
        ))
        let item = makeItem(filename: "Invoice 2026_7_2.pdf")

        XCTAssertEqual(sanitizer.suggestedFilename(for: item), "Invoice_2026-07-02.pdf")
        XCTAssertEqual(sanitizer.collisionFilename(original: "Invoice_2026-07-02.pdf", ordinal: 2), "Invoice_2026-07-02 (2).pdf")
    }

    func testLimitsBasenameByUTF8Length() {
        let result = FilenameSanitizer(maximumBasenameUTF8Length: 32)
            .normalizedBasename(String(repeating: "é", count: 100))

        XCTAssertLessThanOrEqual(result.utf8.count, 32)
    }
}
