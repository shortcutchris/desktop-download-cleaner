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

    func testLimitsBasenameByUTF8Length() {
        let result = FilenameSanitizer(maximumBasenameUTF8Length: 32)
            .normalizedBasename(String(repeating: "é", count: 100))

        XCTAssertLessThanOrEqual(result.utf8.count, 32)
    }
}

