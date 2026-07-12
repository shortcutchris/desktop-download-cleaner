import DesktopCleanerCore
import XCTest

final class RuleEngineTests: XCTestCase {
    func testFirstEnabledOrderedRuleWins() {
        let item = makeItem(filename: "Invoice-2026.pdf")
        let later = UserRule(
            name: "All PDFs",
            order: 2,
            condition: RuleCondition(kind: .pathExtension, pattern: "pdf"),
            category: .documents
        )
        let first = UserRule(
            name: "Invoices",
            order: 1,
            condition: RuleCondition(kind: .filename, pattern: "Invoice-*"),
            category: .documents,
            basenameTemplate: "Accounting – {basename}"
        )

        let evaluation = RuleEngine(rules: [later, first]).evaluate(item)

        XCTAssertEqual(evaluation?.ruleID, first.id)
        XCTAssertEqual(evaluation?.suggestedBasename, "Accounting – Invoice-2026")
    }

    func testDisabledRuleDoesNotMatch() {
        let rule = UserRule(
            name: "Disabled",
            isEnabled: false,
            order: 0,
            condition: RuleCondition(kind: .filename, pattern: "*"),
            category: .archives
        )

        XCTAssertNil(RuleEngine(rules: [rule]).evaluate(makeItem(filename: "report.pdf")))
    }

    func testIdenticalConditionsWithDifferentOutcomesConflict() {
        let condition = RuleCondition(kind: .pathExtension, pattern: "zip")
        let first = UserRule(name: "Archives", order: 0, condition: condition, category: .archives)
        let second = UserRule(name: "Projects", order: 1, condition: condition, category: .codeAndProjects)

        let conflicts = RuleEngine(rules: [first, second]).conflicts()

        XCTAssertEqual(conflicts.count, 1)
        XCTAssertEqual(conflicts.first?.firstRuleID, first.id)
        XCTAssertEqual(conflicts.first?.secondRuleID, second.id)
    }
}

