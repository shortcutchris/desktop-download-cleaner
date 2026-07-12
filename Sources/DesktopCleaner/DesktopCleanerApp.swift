import AppKit
import SwiftUI

@main
struct DesktopCleanerApp: App {
    @StateObject private var model = AppModel()

    init() {
        guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let icon = NSImage(contentsOf: iconURL) else { return }
        NSApplication.shared.applicationIconImage = icon
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(model)
                .frame(minWidth: 980, minHeight: 640)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Add Source Folder…") { model.chooseSourceFolder() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                Button("Scan Selected Source") { model.scanSelectedSource() }
                    .keyboardShortcut("r", modifiers: [.command])
                    .disabled(model.selectedSourceID == nil || model.isBusy)
            }
        }

        MenuBarExtra("Desktop Cleaner", systemImage: "sparkles.rectangle.stack") {
            MenuBarView()
                .environmentObject(model)
        }

        Settings {
            SettingsView()
                .environmentObject(model)
                .frame(width: 680, height: 520)
        }
    }
}
