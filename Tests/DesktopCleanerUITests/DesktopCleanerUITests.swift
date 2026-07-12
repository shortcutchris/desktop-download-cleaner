import XCTest

final class DesktopCleanerUITests: XCTestCase {
    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        if app.state != .notRunning {
            app.terminate()
        }
        app.launch()
        return app
    }

    @MainActor
    func testSafeDemoReviewStageAndUndo() {
        continueAfterFailure = false
        let app = launchApp()
        defer { app.terminate() }
        let demoButton = app.buttons["welcome.tryDemo"]
        XCTAssertTrue(demoButton.waitForExistence(timeout: 5))
        demoButton.click()

        let firstProposalApproval = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH 'plan.approval.'"))
            .firstMatch
        XCTAssertTrue(firstProposalApproval.waitForExistence(timeout: 8))
        let mainWindow = app.windows.firstMatch
        mainWindow.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.04)).click()

        let filename = app.textFields["inspector.filename"]
        XCTAssertTrue(filename.waitForExistence(timeout: 8))
        XCTAssertTrue(filename.isHittable)
        filename.click()
        filename.typeKey("a", modifierFlags: .command)
        filename.typeText("Quarterly Export.csv")
        XCTAssertEqual(filename.value as? String, "Quarterly Export.csv")

        XCTAssertTrue(firstProposalApproval.isHittable)
        firstProposalApproval.click()

        let stageButton = app.buttons["toolbar.stage"]
        XCTAssertTrue(stageButton.waitForExistence(timeout: 3))
        let enabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true"),
            object: stageButton
        )
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 8), .completed)
        app.activate()
        stageButton.click()

        let undoButton = app.buttons["Undo Complete Session"]
        XCTAssertTrue(undoButton.waitForExistence(timeout: 8))
        undoButton.click()

        XCTAssertTrue(app.staticTexts["Session restored"].waitForExistence(timeout: 8))
    }
}
