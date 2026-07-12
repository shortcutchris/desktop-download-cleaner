import DesktopCleanerCore
import XCTest

final class ClassificationEngineTests: XCTestCase {
    func testUTIClassifiesDocument() {
        let result = ClassificationEngine().classify(makeItem(filename: "report.bin", typeIdentifier: "com.adobe.pdf"))

        XCTAssertEqual(result.category, .documents)
        XCTAssertEqual(result.confidence, .high)
    }

    func testScreenshotRulePrecedesGenericImage() {
        let result = ClassificationEngine().classify(
            makeItem(filename: "Screenshot 2026-07-12 at 10.30.00.png", typeIdentifier: "public.png")
        )

        XCTAssertEqual(result.category, .screenshots)
    }

    func testPackageStatusPrecedesExtensionFallback() {
        let result = ClassificationEngine().classify(makeItem(filename: "Example.app", isPackage: true))

        XCTAssertEqual(result.category, .installers)
        XCTAssertEqual(result.confidence, .high)
    }

    func testSensitiveDefaultsRemainProtected() {
        for filename in [".env", "server.pem", "id_ed25519_work", "cache.sqlite"] {
            let result = ClassificationEngine().classify(makeItem(filename: filename))
            XCTAssertEqual(result.category, .sensitive, filename)
            XCTAssertTrue(result.isSensitive, filename)
        }
    }

    func testUserExclusionWinsBeforeClassification() {
        let engine = ClassificationEngine(exclusions: [
            ExclusionRule(kind: .relativePath, pattern: "Private/*")
        ])
        let result = engine.classify(
            makeItem(filename: "photo.png", typeIdentifier: "public.png", relativePath: "Private/photo.png")
        )

        XCTAssertTrue(result.isExcluded)
        XCTAssertEqual(result.category, .unclear)
    }

    func testExtensionExclusionIsCaseInsensitive() {
        let engine = ClassificationEngine(exclusions: [
            ExclusionRule(kind: .pathExtension, pattern: "TMP")
        ])

        XCTAssertTrue(engine.classify(makeItem(filename: "ignored.tmp")).isExcluded)
    }

    func testUnknownHiddenFileIsExcludedByDefault() {
        let base = makeItem(filename: ".cache")
        let hidden = ScannedItem(
            sourceID: base.sourceID,
            relativePath: base.relativePath,
            filename: base.filename,
            pathExtension: base.pathExtension,
            identity: base.identity,
            isHidden: true
        )

        let result = ClassificationEngine().classify(hidden)

        XCTAssertTrue(result.isExcluded)
        XCTAssertFalse(result.isSensitive)
    }
}
