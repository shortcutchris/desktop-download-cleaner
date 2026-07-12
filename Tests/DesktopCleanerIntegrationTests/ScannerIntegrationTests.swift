import DesktopCleanerCore
import DesktopCleanerServices
import Foundation
import XCTest

final class ScannerIntegrationTests: XCTestCase {
    private var fixtureRoot: URL!

    override func setUpWithError() throws {
        fixtureRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopCleanerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let fixtureRoot {
            try? FileManager.default.removeItem(at: fixtureRoot)
        }
    }

    func testScanAndPlanAreReadOnly() async throws {
        try Data("invoice".utf8).write(to: fixtureRoot.appendingPathComponent("Invoice (1).pdf"))
        try Data("image".utf8).write(to: fixtureRoot.appendingPathComponent("Screenshot 2026-07-12.png"))
        let nested = fixtureRoot.appendingPathComponent("Nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data("source".utf8).write(to: nested.appendingPathComponent("main.swift"))
        let before = try snapshot(of: fixtureRoot)
        let source = SourceFolder(displayName: "Fixture", scanDepth: 1)

        let plan = try await LocalCleanupService().scanAndPlan(
            source: source,
            at: fixtureRoot,
            sessionDirectoryName: "Test Session"
        )
        let after = try snapshot(of: fixtureRoot)

        XCTAssertEqual(before, after)
        XCTAssertEqual(plan.items.count, 3)
        XCTAssertEqual(Set(plan.items.map { $0.classification.category }), [.documents, .screenshots, .codeAndProjects])
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixtureRoot.appendingPathComponent("Test Session").path))
    }

    func testDepthLimitDoesNotTraverseOrFollowDirectorySymlink() async throws {
        let nested = fixtureRoot.appendingPathComponent("Nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data("nested".utf8).write(to: nested.appendingPathComponent("inside.txt"))
        try FileManager.default.createSymbolicLink(
            at: fixtureRoot.appendingPathComponent("Nested Link"),
            withDestinationURL: nested
        )
        try Data("top".utf8).write(to: fixtureRoot.appendingPathComponent("top.txt"))

        let shallow = try await Scanner().scan(
            source: SourceFolder(displayName: "Fixture", scanDepth: 0),
            at: fixtureRoot
        )
        let deep = try await Scanner().scan(
            source: SourceFolder(displayName: "Fixture", scanDepth: 1),
            at: fixtureRoot
        )

        XCTAssertEqual(Set(shallow.map(\.filename)), ["Nested Link", "top.txt"])
        XCTAssertEqual(Set(deep.map(\.filename)), ["Nested Link", "inside.txt", "top.txt"])
        XCTAssertTrue(shallow.first(where: { $0.filename == "Nested Link" })?.isSymbolicLink == true)
    }

    func testHiddenSensitiveFileIsRecordedAndProtected() async throws {
        try Data("secret".utf8).write(to: fixtureRoot.appendingPathComponent(".env"))

        let items = try await Scanner().scan(
            source: SourceFolder(displayName: "Fixture"),
            at: fixtureRoot
        )
        let environment = try XCTUnwrap(items.first(where: { $0.filename == ".env" }))
        let classification = ClassificationEngine().classify(environment)

        XCTAssertTrue(environment.isHidden)
        XCTAssertEqual(classification.category, .sensitive)
        XCTAssertTrue(classification.isSensitive)
    }

    func testConfiguredExclusionRemovesMatchingFileFromPlan() async throws {
        try Data("temporary".utf8).write(to: fixtureRoot.appendingPathComponent("scratch.tmp"))
        try Data("document".utf8).write(to: fixtureRoot.appendingPathComponent("keep.pdf"))

        let plan = try await LocalCleanupService().scanAndPlan(
            source: SourceFolder(displayName: "Fixture"),
            at: fixtureRoot,
            sessionDirectoryName: "Session",
            exclusions: [ExclusionRule(kind: .filename, pattern: "*.tmp")]
        )

        XCTAssertEqual(plan.items.map(\.scannedItem.filename), ["keep.pdf"])
    }

    func testMinimumAgeSkipsRecentFilesButKeepsOlderFiles() async throws {
        let recent = fixtureRoot.appendingPathComponent("recent.pdf")
        let old = fixtureRoot.appendingPathComponent("old.pdf")
        try Data("recent".utf8).write(to: recent)
        try Data("old".utf8).write(to: old)
        try FileManager.default.setAttributes(
            [.modificationDate: try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -30, to: Date()))],
            ofItemAtPath: old.path
        )

        let plan = try await LocalCleanupService().scanAndPlan(
            source: SourceFolder(displayName: "Fixture"),
            at: fixtureRoot,
            sessionDirectoryName: "Session",
            minimumAgeDays: 7
        )

        XCTAssertEqual(plan.items.map(\.scannedItem.filename), ["old.pdf"])
    }

    func testDuplicateDetectionHashesOnlySameSizeEligibleFilesAndMarksLaterCopy() async throws {
        try Data("identical-content".utf8).write(to: fixtureRoot.appendingPathComponent("a.pdf"))
        try Data("identical-content".utf8).write(to: fixtureRoot.appendingPathComponent("b.pdf"))
        try Data("different".utf8).write(to: fixtureRoot.appendingPathComponent("c.pdf"))
        try Data("identical-content".utf8).write(to: fixtureRoot.appendingPathComponent("secret.pem"))

        let plan = try await LocalCleanupService().scanAndPlan(
            source: SourceFolder(displayName: "Fixture"),
            at: fixtureRoot,
            sessionDirectoryName: "Session"
        )

        XCTAssertEqual(plan.items.first(where: { $0.scannedItem.filename == "a.pdf" })?.classification.category, .documents)
        let duplicate = try XCTUnwrap(plan.items.first(where: { $0.scannedItem.filename == "b.pdf" }))
        XCTAssertEqual(duplicate.classification.category, .duplicates)
        XCTAssertTrue(duplicate.classification.reason.contains("a.pdf"))
        XCTAssertEqual(plan.items.first(where: { $0.scannedItem.filename == "secret.pem" })?.classification.category, .sensitive)
    }

    private func snapshot(of root: URL) throws -> [String: FileSnapshot] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in false }
        ) else { return [:] }

        var result: [String: FileSnapshot] = [:]
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(keys))
            let path = String(url.path.dropFirst(root.path.count + 1))
            let contents = values.isDirectory == true || values.isSymbolicLink == true ? nil : try Data(contentsOf: url)
            result[path] = FileSnapshot(
                isDirectory: values.isDirectory == true,
                isSymbolicLink: values.isSymbolicLink == true,
                size: values.fileSize,
                modificationDate: values.contentModificationDate,
                contents: contents
            )
            if values.isSymbolicLink == true { enumerator.skipDescendants() }
        }
        return result
    }
}

private struct FileSnapshot: Equatable {
    let isDirectory: Bool
    let isSymbolicLink: Bool
    let size: Int?
    let modificationDate: Date?
    let contents: Data?
}
