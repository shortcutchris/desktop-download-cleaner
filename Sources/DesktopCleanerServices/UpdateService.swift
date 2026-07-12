import Foundation
import Sparkle

@MainActor
public final class UpdateService {
    public let isEnabled: Bool
    private let controller: SPUStandardUpdaterController?

    public init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
        controller = isEnabled
            ? SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
            : nil
    }

    public var canCheckForUpdates: Bool {
        isEnabled && controller?.updater.canCheckForUpdates == true
    }

    public var automaticallyChecksForUpdates: Bool {
        isEnabled && controller?.updater.automaticallyChecksForUpdates == true
    }

    @discardableResult
    public func checkForUpdates() -> Bool {
        guard canCheckForUpdates else { return false }
        controller?.checkForUpdates(nil)
        return true
    }

    public func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        guard isEnabled else { return }
        controller?.updater.automaticallyChecksForUpdates = enabled
    }
}
