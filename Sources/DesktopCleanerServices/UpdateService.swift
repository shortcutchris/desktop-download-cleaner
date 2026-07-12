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

    public func checkForUpdates() {
        guard isEnabled else { return }
        controller?.checkForUpdates(nil)
    }
}

