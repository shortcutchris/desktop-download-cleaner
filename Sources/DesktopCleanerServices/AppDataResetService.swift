import Foundation

public actor AppDataResetService {
    private let appSupportURL: URL
    private let defaultsSuiteName: String?

    public init(
        appSupportURL: URL? = nil,
        defaultsSuiteName: String? = nil
    ) {
        if let appSupportURL {
            self.appSupportURL = appSupportURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.appSupportURL = base.appendingPathComponent("DesktopCleaner", isDirectory: true)
        }
        self.defaultsSuiteName = defaultsSuiteName
    }

    public func resetMetadataAndSettings() throws {
        if FileManager.default.fileExists(atPath: appSupportURL.path) {
            try FileManager.default.removeItem(at: appSupportURL)
        }

        let keys = [
            "authorizedSourceFolders",
            "defaultFileOperation",
            "aiPrivacyLevel",
            "notificationsEnabled"
        ]
        let defaults = defaultsSuiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
        for key in keys { defaults.removeObject(forKey: key) }
    }
}
