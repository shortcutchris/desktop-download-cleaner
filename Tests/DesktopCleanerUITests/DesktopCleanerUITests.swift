import XCTest

final class DesktopCleanerUITests: XCTestCase {
    @MainActor
    private func launchApp(language: String = "en") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-appLanguage", language]
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

    @MainActor
    func testGermanInterfaceCanSwitchToEnglishImmediately() {
        continueAfterFailure = false
        let app = launchApp(language: "de")
        defer { app.terminate() }

        XCTAssertTrue(app.buttons["Sichere Demo ausprobieren"].waitForExistence(timeout: 5))

        app.typeKey(",", modifierFlags: .command)
        let languagePicker = app.popUpButtons["settings.language"]
        XCTAssertTrue(languagePicker.waitForExistence(timeout: 5))
        languagePicker.click()
        let englishOption = app.menuItems["Englisch"]
        XCTAssertTrue(englishOption.waitForExistence(timeout: 3))
        englishOption.click()

        XCTAssertTrue(app.buttons["Try Safe Demo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[
            "The interface updates immediately. File names, saved rules, and stable review-folder paths are never rewritten."
        ].waitForExistence(timeout: 5))
    }
}
