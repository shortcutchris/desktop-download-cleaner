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
                Button("Approve Safe Proposals") { model.approveSafeItems() }
                    .keyboardShortcut("a", modifiers: [.command, .shift])
                    .disabled(model.plan == nil || model.isBusy)
                Button("Stage Approved Files") { model.stageApprovedItems() }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(model.approvedCount == 0 || model.reviewRoot == nil || model.isBusy)
                Button("Quick Look Selected Proposal") { model.quickLookSelected() }
                    .keyboardShortcut(.space, modifiers: [])
                    .disabled(model.selectedPlanItem == nil)
            }
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(model)
        } label: {
            Label(
                model.pendingCount == 0 ? "Desktop Cleaner" : "\(model.pendingCount) pending",
                systemImage: model.pendingCount == 0 ? "sparkles.rectangle.stack" : "tray.full.fill"
            )
        }

        Settings {
            SettingsView()
                .environmentObject(model)
                .frame(width: 680, height: 520)
        }
    }
}
