import DesktopCleanerServices
import XCTest

final class UpdateServiceTests: XCTestCase {
    @MainActor
    func testDisabledServiceNeverChecksOrChangesAutomaticPreference() {
        let service = UpdateService(isEnabled: false)

        XCTAssertFalse(service.canCheckForUpdates)
        XCTAssertFalse(service.automaticallyChecksForUpdates)
        XCTAssertFalse(service.checkForUpdates())

        service.setAutomaticallyChecksForUpdates(true)
        XCTAssertFalse(service.automaticallyChecksForUpdates)
    }
}
