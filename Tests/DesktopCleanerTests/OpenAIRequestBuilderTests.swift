import DesktopCleanerCore
import DesktopCleanerServices
import Foundation
import XCTest

final class OpenAIRequestBuilderTests: XCTestCase {
    func testMetadataRequestUsesResponsesStructuredOutputsWithoutContentOrPaths() throws {
        let item = ScannedItem(
            sourceID: UUID(),
            relativePath: "Private/report.pdf",
            filename: "report.pdf",
            pathExtension: "pdf",
            typeIdentifier: "com.adobe.pdf",
            size: 42_000,
            identity: "identity"
        )

        let request = try OpenAIRequestBuilder().makeMetadataRequest(items: [item])
        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let input = try XCTUnwrap(object["input"] as? String)
        let text = try XCTUnwrap(object["text"] as? [String: Any])
        let format = try XCTUnwrap(text["format"] as? [String: Any])

        XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/responses")
        XCTAssertEqual(object["store"] as? Bool, false)
        XCTAssertEqual(object["model"] as? String, "gpt-5.6-luna")
        XCTAssertEqual(format["type"] as? String, "json_schema")
        XCTAssertEqual(format["strict"] as? Bool, true)
        XCTAssertTrue(input.contains("report.pdf"))
        XCTAssertTrue(input.contains("10_kb_to_1_mb"))
        XCTAssertFalse(input.contains("Private/report.pdf"))
        XCTAssertFalse(input.contains("identity"))
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testQualityPreferenceChangesOnlyReasoningEffort() throws {
        let item = makeItem(filename: "report.pdf")
        let request = try OpenAIRequestBuilder().makeMetadataRequest(items: [item], quality: .thorough)
        let payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any]
        )
        let reasoning = try XCTUnwrap(payload["reasoning"] as? [String: Any])

        XCTAssertEqual(reasoning["effort"] as? String, "high")
        XCTAssertEqual(payload["store"] as? Bool, false)
    }

    func testRequestedInterfaceLanguageIsAppliedOnlyToProposalReasons() throws {
        let request = try OpenAIRequestBuilder().makeMetadataRequest(
            items: [makeItem(filename: "report.pdf")],
            responseLanguage: "German"
        )
        let payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any]
        )
        let instructions = try XCTUnwrap(payload["instructions"] as? String)

        XCTAssertTrue(instructions.contains("Write each reason in German."))
        XCTAssertFalse(try XCTUnwrap(payload["input"] as? String).contains("German"))
    }
}
