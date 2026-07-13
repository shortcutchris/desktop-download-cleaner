import AppKit
import SwiftUI

@main
struct DesktopCleanerApp: App {
    @StateObject private var model = AppModel()
    @AppStorage("menuBarEnabled") private var menuBarExtraEnabled = true

    init() {
        guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let icon = NSImage(contentsOf: iconURL) else { return }
        NSApplication.shared.applicationIconImage = icon
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(model)
                .environment(\.locale, model.appLanguage.locale)
                .frame(minWidth: 980, minHeight: 640)
        }
        .commands {
            DesktopCleanerCommands(model: model)
        }

        Window(model.localized("Desktop Cleaner Help"), id: "help") {
            HelpView()
                .environmentObject(model)
                .environment(\.locale, model.appLanguage.locale)
        }
        .defaultSize(width: 980, height: 700)

        MenuBarExtra(isInserted: $menuBarExtraEnabled) {
            MenuBarView()
                .environmentObject(model)
                .environment(\.locale, model.appLanguage.locale)
        } label: {
            Label(
                model.pendingCount == 0
                    ? model.localized("Desktop Cleaner")
                    : model.localized("%@ pending", String(model.pendingCount)),
                systemImage: model.pendingCount == 0 ? "sparkles.rectangle.stack" : "tray.full.fill"
            )
        }

        Settings {
            SettingsView()
                .environmentObject(model)
                .environment(\.locale, model.appLanguage.locale)
                .frame(width: 780, height: 580)
        }
    }
}

private struct DesktopCleanerCommands: Commands {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button(model.localized("Desktop Cleaner Help")) {
                model.requestHelpPresentation()
                openWindow(id: "help")
            }
            .keyboardShortcut("?", modifiers: [.command])
        }
        CommandGroup(after: .newItem) {
            Button(model.localized("Add Source Folder…")) { model.chooseSourceFolder() }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            Button(model.localized("Scan Selected Source")) { model.scanSelectedSource() }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(model.selectedSourceID == nil || model.isBusy)
            Button(model.localized("Approve Safe Proposals")) { model.approveSafeItems() }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .disabled(model.plan == nil || model.isBusy)
            Button(model.localized("Select All Visible Proposals")) { model.selectAllVisibleItems() }
                .keyboardShortcut("a", modifiers: [.command, .option])
                .disabled(model.plan == nil || model.isBusy)
            Button(model.localized("Approve Selected Safe Proposals")) { model.approveSelectedItems() }
                .keyboardShortcut(.return, modifiers: [.command, .shift])
                .disabled(model.selectedPlanItemIDs.isEmpty || model.isBusy)
            Button(model.localized("Stage Approved Files")) { model.stageApprovedItems() }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(model.approvedCount == 0 || model.reviewRoot == nil || model.isBusy)
            Button(model.localized("Quick Look Selected Proposal")) { model.quickLookSelected() }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(model.selectedPlanItem == nil)
        }
        CommandGroup(after: .appInfo) {
            Button(model.localized("Check for Updates…")) { model.checkForUpdates() }
                .disabled(!model.canCheckForUpdates)
        }
    }
}
