import DesktopCleanerServices
import Foundation
import XCTest

final class AppDataResetIntegrationTests: XCTestCase {
    func testResetRemovesOnlyInjectedAppDataAndSettings() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopCleanerReset-\(UUID())", isDirectory: true)
        let appData = root.appendingPathComponent("AppData", isDirectory: true)
        let userFiles = root.appendingPathComponent("UserFiles", isDirectory: true)
        let userFile = userFiles.appendingPathComponent("keep-me.txt")
        try FileManager.default.createDirectory(at: appData, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: userFiles, withIntermediateDirectories: true)
        try Data("metadata".utf8).write(to: appData.appendingPathComponent("sessions.json"))
        try Data("important".utf8).write(to: userFile)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }

        let suiteName = "DesktopCleanerResetTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.set("move", forKey: "defaultFileOperation")
        defaults.set(14, forKey: "minimumAgeDays")
        defaults.set(true, forKey: "unrelatedSetting")
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        try await AppDataResetService(appSupportURL: appData, defaultsSuiteName: suiteName)
            .resetMetadataAndSettings()

        XCTAssertFalse(FileManager.default.fileExists(atPath: appData.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: userFile.path))
        XCTAssertNil(defaults.object(forKey: "defaultFileOperation"))
        XCTAssertNil(defaults.object(forKey: "minimumAgeDays"))
        XCTAssertEqual(defaults.bool(forKey: "unrelatedSetting"), true)
    }
}
