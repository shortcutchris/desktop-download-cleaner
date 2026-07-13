import XCTest

final class DesktopCleanerUITests: XCTestCase {
    @MainActor
    private func launchApp(language: String = "en") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launchEnvironment["DESKTOP_CLEANER_UI_TESTING"] = "1"
        app.launchEnvironment["DESKTOP_CLEANER_LANGUAGE"] = language
        app.launch()
        return app
    }

    @MainActor
    func testSafeDemoPresentsReviewPlan() {
        continueAfterFailure = false
        let app = launchApp()
        defer { app.terminate() }
        let demoButton = app.descendants(matching: .any)["welcome.tryDemo"]
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

        let demoButton = app.descendants(matching: .any)["welcome.tryDemo"]
        XCTAssertTrue(demoButton.waitForExistence(timeout: 5))
        XCTAssertEqual(demoButton.label, "Sichere Demo ausprobieren")

        app.typeKey(",", modifierFlags: .command)
        let languagePicker = app.popUpButtons["settings.language"]
        XCTAssertTrue(languagePicker.waitForExistence(timeout: 5))
        languagePicker.click()
        let englishOption = app.menuItems["Englisch"]
        XCTAssertTrue(englishOption.waitForExistence(timeout: 3))
        englishOption.click()

        XCTAssertTrue(demoButton.waitForExistence(timeout: 5))
        XCTAssertEqual(demoButton.label, "Try Safe Demo")
        XCTAssertTrue(app.staticTexts[
            "The interface updates immediately. File names, saved rules, and stable review-folder paths are never rewritten."
        ].waitForExistence(timeout: 5))
    }

    @MainActor
    func testGermanInteractiveHelpTourIsSafeAndLocalized() {
        continueAfterFailure = false
        let app = launchApp(language: "de")
        defer { app.terminate() }

        let helpButton = app.descendants(matching: .any)["welcome.help"]
        XCTAssertTrue(helpButton.waitForExistence(timeout: 5))
        XCTAssertEqual(helpButton.label, "Hilfe & Anleitung")
        helpButton.click()

        XCTAssertTrue(app.windows["Desktop-Cleaner-Hilfe"].waitForExistence(timeout: 5))
        let stepTitle = app.descendants(matching: .any)["help.tour.stepTitle"]
        let actionButton = app.descendants(matching: .any)["help.tour.action"]
        let nextButton = app.descendants(matching: .any)["help.tour.next"]
        XCTAssertTrue(stepTitle.waitForExistence(timeout: 5))

        XCTAssertTrue(actionButton.waitForExistence(timeout: 3))
        XCTAssertEqual(actionButton.label, "Beispiel auswählen")
        actionButton.click()
        XCTAssertEqual(actionButton.label, "Ausgewählt")

        XCTAssertTrue(nextButton.waitForExistence(timeout: 3))
        XCTAssertEqual(nextButton.label, "Weiter")
        nextButton.click()
        XCTAssertTrue(actionButton.waitForExistence(timeout: 3))
        XCTAssertEqual(actionButton.label, "Beispielplan erstellen")

        XCTAssertTrue(app.staticTexts[
            "Diese Einführung ist eine Simulation. Sie liest, erstellt, verschiebt oder löscht niemals Dateien."
        ].waitForExistence(timeout: 3))
    }

    @MainActor
    func testHelpMenuCommandOpensEnglishGuide() {
        continueAfterFailure = false
        let app = launchApp(language: "en")
        defer { app.terminate() }

        let helpMenu = app.menuBars.menuBarItems["Help"]
        XCTAssertTrue(helpMenu.waitForExistence(timeout: 3))
        helpMenu.click()
        let helpCommand = helpMenu.descendants(matching: .menuItem)["Desktop Cleaner Help"]
        XCTAssertTrue(helpCommand.waitForExistence(timeout: 3))
        helpCommand.click()

        XCTAssertTrue(app.windows["Desktop Cleaner Help"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Interactive Guided Tour"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testGermanBuildSummaryOpensChangelogSettings() {
        continueAfterFailure = false
        let app = launchApp(language: "de")
        defer { app.terminate() }

        let changelogButton = app.descendants(matching: .any)["status.changelog"]
        XCTAssertTrue(changelogButton.waitForExistence(timeout: 5))
        XCTAssertTrue(changelogButton.label.contains("Version 1.3.0"))
        XCTAssertTrue(changelogButton.label.contains("Build 9"))
        changelogButton.click()

        let changelog = app.descendants(matching: .any)["settings.changelog"]
        XCTAssertTrue(changelog.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Versionsverlauf"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Installiert: Version 1.3.0 · Build 9"].waitForExistence(timeout: 3))
        let latestSummary = app.descendants(matching: .any)["changelog.release.1.3.0.summary"]
        XCTAssertTrue(latestSummary.waitForExistence(timeout: 3))
        XCTAssertTrue(
            latestSummary.label.contains(
                "Offline-Hilfe, interaktive Einführung und ein Versionsverlauf in der App."
            )
        )
    }
}
