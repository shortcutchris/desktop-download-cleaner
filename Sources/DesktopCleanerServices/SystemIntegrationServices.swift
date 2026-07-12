import Foundation
import ServiceManagement
import UserNotifications

@MainActor
public final class LaunchAtLoginService {
    public init() {}

    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else if SMAppService.mainApp.status == .enabled {
            try SMAppService.mainApp.unregister()
        }
    }
}

public actor NotificationService {
    public init() {}

    public func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    public func notifyStagingComplete(itemCount: Int, sessionName: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Cleanup session staged"
        content.body = "\(itemCount) items are ready in \(sessionName)."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "desktop-cleaner-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try await UNUserNotificationCenter.current().add(request)
    }
}

