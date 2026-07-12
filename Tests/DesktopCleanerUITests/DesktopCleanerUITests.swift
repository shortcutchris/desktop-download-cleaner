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
    func testSafeDemoPresentsReviewPlan() {
        continueAfterFailure = false
        let app = launchApp()
        defer { app.terminate() }
        let demoButton = app.buttons["welcome.tryDemo"]
        XCTAssertTrue(demoButton.waitForExistence(timeout: 5))
        demoButton.click()

        XCTAssertTrue(app.windows["Cleanup Plan · 6"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.textFields["inspector.filename"].waitForExistence(timeout: 8))
        let stageButton = app.buttons.matching(identifier: "toolbar.stage").firstMatch
        XCTAssertTrue(stageButton.waitForExistence(timeout: 3))
        XCTAssertFalse(stageButton.isEnabled)
    }
}
