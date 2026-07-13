import DesktopCleanerCore
import SwiftUI

enum SettingsTab: Hashable {
    case general
    case sources
    case review
    case renaming
    case rules
    case ai
    case updates
    case changelog
}

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView(selection: $model.selectedSettingsTab) {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            SourceSettingsView()
                .tabItem { Label("Sources", systemImage: "folder") }
                .tag(SettingsTab.sources)
            ReviewSettingsView()
                .tabItem { Label("Review", systemImage: "shippingbox") }
                .tag(SettingsTab.review)
            RenamingSettingsView()
                .tabItem { Label("Renaming", systemImage: "textformat") }
                .tag(SettingsTab.renaming)
            RuleSettingsView()
                .tabItem { Label("Rules", systemImage: "list.bullet.rectangle") }
                .tag(SettingsTab.rules)
            AISettingsView()
                .tabItem { Label("AI", systemImage: "sparkles") }
                .tag(SettingsTab.ai)
            UpdateSettingsView()
                .tabItem { Label("Updates", systemImage: "arrow.triangle.2.circlepath") }
                .tag(SettingsTab.updates)
            ChangelogSettingsView()
                .tabItem { Label("Changelog", systemImage: "clock.arrow.circlepath") }
                .tag(SettingsTab.changelog)
        }
        .padding(18)
        .confirmationDialog(
            "Delete all Desktop Cleaner app data?",
            isPresented: $model.showsResetConfirmation
        ) {
            Button("Delete App Data", role: .destructive) { model.resetAllAppData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Bookmarks, settings, rules, scan cache, journals, sessions, and the Keychain API key will be removed. User files are never deleted.")
        }
        .sheet(isPresented: $model.showsDiagnosticsPreview) {
            DiagnosticsPreviewSheet()
                .environmentObject(model)
        }
    }
}

private struct GeneralSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Form {
            Section("Language") {
                Picker("App language", selection: $model.appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(model.localized(language.displayNameKey)).tag(language)
                    }
                }
                .accessibilityIdentifier("settings.language")
                Text("The interface updates immediately. File names, saved rules, and stable review-folder paths are never rewritten.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings.languageDescription")
            }
            Toggle("Launch at login", isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))
            Toggle("Show notifications when staging completes", isOn: $model.notificationsEnabled)
            Toggle("Show menu bar item", isOn: $model.menuBarEnabled)
            Section("Help") {
                Button {
                    openWindow(id: "help")
                } label: {
                    Label("Open Help & Guide", systemImage: "questionmark.circle")
                }
                .accessibilityIdentifier("settings.openHelp")
                Text("The help center is available offline and follows the selected app language.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Diagnostics") {
                Button("Preview Redacted Debug Export…") { model.prepareDiagnosticsExport() }
                    .accessibilityIdentifier("settings.previewDiagnostics")
                Text("The preview is exactly what will be exported. File names, paths, file contents, API keys, and model payloads are excluded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Privacy") {
                Button("Delete All App Data…", role: .destructive) {
                    model.showsResetConfirmation = true
                }
                Text("This removes only Desktop Cleaner metadata and credentials. It never deletes user files.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct ReviewSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("Visible review folder") {
                LabeledContent("Current", value: model.reviewRoot?.displayName ?? model.localized("Not selected"))
                Button("Choose Review Folder…") { model.chooseReviewRoot() }
            }
            Section("Staging") {
                Picker("Default operation", selection: $model.operation) {
                    Text("Move").tag(FileOperation.move)
                    Text("Copy").tag(FileOperation.copy)
                }
                Picker("Session history", selection: $model.sessionHistoryRetention) {
                    ForEach(SessionHistoryRetention.allCases, id: \.self) { policy in
                        Text(model.localized(policy.displayName)).tag(policy)
                    }
                }
                Text("Retention removes only finalized or rolled-back metadata. Staged files and undoable sessions are never pruned.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Label("Existing files are never overwritten. Move and copy operations can both be undone.", systemImage: "checkmark.shield.fill")
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}

private struct RenamingSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Picker("Naming style", selection: $model.filenameNamingStyle) {
                ForEach(FilenameNamingStyle.allCases, id: \.self) { style in
                    Text(model.localized(style.displayName)).tag(style)
                }
            }
            Picker("Detected dates", selection: $model.filenameDateStyle) {
                ForEach(FilenameDateStyle.allCases, id: \.self) { style in
                    Text(model.localized(style.displayName)).tag(style)
                }
            }
            Picker("Collision suffix", selection: $model.collisionSuffixStyle) {
                ForEach(CollisionSuffixStyle.allCases, id: \.self) { style in
                    Text(model.localized(style.displayName)).tag(style)
                }
            }
            Text("Styles affect new plans only. The real extension is always preserved and every result is sanitized locally.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}

private struct SourceSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("Authorized sources") {
                ForEach(model.sources) { source in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Toggle(isOn: Binding(
                                get: { source.isEnabled },
                                set: { model.updateSource(id: source.id, isEnabled: $0) }
                            )) {
                                Label(source.displayName, systemImage: "folder.fill")
                            }
                            .accessibilityLabel(model.localized("Enable %@", source.displayName))
                            Spacer()
                            Button("Remove", role: .destructive) { model.removeSource(source) }
                        }
                        Stepper(
                            model.localized(
                                "Scan depth: %@",
                                source.scanDepth == 0
                                    ? model.localized("direct children")
                                    : model.localized("%@ level(s)", String(source.scanDepth))
                            ),
                            value: Binding(
                                get: { source.scanDepth },
                                set: { model.updateSource(id: source.id, scanDepth: $0) }
                            ),
                            in: 0...5
                        )
                        .font(.caption)
                        .accessibilityLabel(model.localized("Scan depth for %@", source.displayName))
                    }
                    .padding(.vertical, 4)
                }
                HStack {
                    Button("Desktop…") { model.chooseDesktopFolder() }
                    Button("Downloads…") { model.chooseDownloadsFolder() }
                    Button("Other Folder…") { model.chooseSourceFolder() }
                }
            }
            Section("Scan policy") {
                Stepper(
                    model.minimumAgeDays == 0
                        ? model.localized("Include files of any age")
                        : model.localized("Only files at least %@ day(s) old", String(model.minimumAgeDays)),
                    value: $model.minimumAgeDays,
                    in: 0...365
                )
                Text("Files without a reliable date remain visible rather than being silently skipped.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Exclusions") {
                ForEach($model.exclusions) { $exclusion in
                    HStack {
                        Picker("Match", selection: $exclusion.kind) {
                            Text("Filename").tag(ExclusionRuleKind.filename)
                            Text("Extension").tag(ExclusionRuleKind.pathExtension)
                            Text("Relative path").tag(ExclusionRuleKind.relativePath)
                        }
                        .labelsHidden()
                        .frame(width: 130)
                        TextField("Glob pattern", text: $exclusion.pattern)
                    }
                }
                .onDelete(perform: model.deleteExclusions)
                Button { model.addExclusion() } label: {
                    Label("Add Exclusion", systemImage: "plus")
                }
                Text("Use * and ? wildcards. Relative-path rules can exclude folders, for example Private/*.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Visible review folder") {
                LabeledContent("Current", value: model.reviewRoot?.displayName ?? model.localized("Not selected"))
                Button("Choose Review Folder…") { model.chooseReviewRoot() }
            }
        }
        .formStyle(.grouped)
        .onDisappear { model.saveExclusions() }
    }
}

private struct RuleSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ordered Local Rules").font(.headline)
                Spacer()
                Button("Import…") { model.importRules() }
                Button("Export…") { model.exportRules() }
                    .disabled(model.rules.isEmpty)
                Button { model.addRule() } label: { Label("Add", systemImage: "plus") }
            }
            if !model.ruleConflicts.isEmpty {
                Label(model.localized(
                    "%@ conflicting rule pair(s). The first enabled rule wins.",
                    String(model.ruleConflicts.count)
                ), systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.callout)
            }
            List {
                ForEach($model.rules) { $rule in
                    HStack(spacing: 10) {
                        Toggle("", isOn: $rule.isEnabled).labelsHidden()
                            .accessibilityLabel(model.localized("Enable rule %@", rule.name))
                        TextField("Name", text: $rule.name)
                        TextField("Pattern", text: $rule.condition.pattern)
                            .frame(width: 130)
                        Picker("Category", selection: $rule.category) {
                            ForEach(ItemCategory.allCases, id: \.self) {
                                Text(model.localizedCategory($0)).tag($0)
                            }
                        }
                        .frame(width: 150)
                    }
                }
                .onDelete(perform: model.deleteRules)
                .onMove(perform: model.moveRules)
            }
            Text("Rules are evaluated locally in order. Sensitive and excluded files always keep their safety classification.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onDisappear { model.saveRules() }
    }
}

private struct AISettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Picker("Maximum data shared", selection: $model.aiPrivacyLevel) {
                Text("Off").tag(AIPrivacyLevel.off)
                Text("Metadata only").tag(AIPrivacyLevel.metadataOnly)
            }
            Picker("Proposal quality", selection: $model.aiQualityPreference) {
                ForEach(AIQualityPreference.allCases, id: \.self) { quality in
                    Text(model.localized(quality.displayName)).tag(quality)
                }
            }
            Text("Quality changes reasoning effort for the same validated metadata-only capability.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("AI is off by default. Sensitive files are always excluded. Metadata requests show their exact data scope before sending.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Section("OpenAI API key") {
                if model.hasAPIKey {
                    Label("Stored securely in macOS Keychain", systemImage: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                    HStack {
                        Button("Test Connection") { model.testAIConnection() }
                        Button("Delete Key", role: .destructive) { model.deleteAPIKey() }
                    }
                } else {
                    SecureField("Paste API key", text: $model.apiKeyDraft)
                        .accessibilityIdentifier("settings.aiKey")
                    Button("Save in Keychain") { model.saveAPIKey() }
                        .disabled(model.apiKeyDraft.isEmpty)
                        .accessibilityIdentifier("settings.saveAIKey")
                }
                Text(model.aiConnectionStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Text and visual preview transmission remain unavailable until separate per-capability consent and extraction safeguards are implemented.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .formStyle(.grouped)
    }
}

private struct UpdateSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            LabeledContent(
                "Version",
                value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                    ?? model.localized("Development")
            )
            Picker("Update channel", selection: .constant("Stable")) {
                Text("Stable").tag("Stable")
            }
            .disabled(true)
            Button("Check for Updates…") { model.checkForUpdates() }
                .disabled(!model.canCheckForUpdates)
                .accessibilityIdentifier("settings.checkForUpdates")
            Toggle("Automatically check for updates", isOn: Binding(
                get: { model.automaticallyChecksForUpdates },
                set: { model.setAutomaticallyChecksForUpdates($0) }
            ))
            Text("Updates come from the public GitHub release feed and are verified with Desktop Cleaner's dedicated Sparkle signature. Automatic checks are opt-in.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}

private struct ChangelogSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var expandedVersions: Set<String> = [AppBuildInfo.version]

    private let manifest = AppChangelogManifest.bundled

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("Version History", systemImage: "clock.arrow.circlepath")
                        .font(.title2.bold())
                    Text(model.localized(
                        "Installed: Version %@ · Build %@",
                        AppBuildInfo.version,
                        AppBuildInfo.build
                    ))
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if manifest.releases.isEmpty {
                    ContentUnavailableView(
                        "Changelog Unavailable",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("The bundled version history could not be loaded.")
                    )
                } else {
                    ForEach(manifest.releases) { release in
                        releaseCard(release)
                    }
                }
            }
            .padding(4)
        }
        .accessibilityIdentifier("settings.changelog")
    }

    private func releaseCard(_ release: AppRelease) -> some View {
        GroupBox {
            DisclosureGroup(isExpanded: Binding(
                get: { expandedVersions.contains(release.version) },
                set: { expanded in
                    if expanded {
                        expandedVersions.insert(release.version)
                    } else {
                        expandedVersions.remove(release.version)
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(release.sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Label(model.localized(section.kind.titleKey), systemImage: section.kind.iconName)
                                .font(.headline)
                                .foregroundStyle(section.kind == .security ? Color.orange : Color.accentColor)
                            ForEach(section.itemKeys, id: \.self) { key in
                                Label(model.localized(key), systemImage: "circle.fill")
                                    .labelStyle(ChangelogItemLabelStyle())
                            }
                        }
                    }
                }
                .padding(.top, 12)
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(model.localized("Version %@", release.version))
                            .font(.headline)
                        Text(model.localized("Build %@", release.build))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        if release.version == AppBuildInfo.version {
                            Text("Installed")
                                .font(.caption2.bold())
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.14), in: Capsule())
                                .foregroundStyle(.tint)
                        }
                        Spacer()
                        Text(localizedDate(release.date))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                    Text(model.localized(release.summaryKey))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("changelog.release.\(release.version).summary")
                        .accessibilityLabel(model.localized(release.summaryKey))
                }
            }
        }
        .accessibilityIdentifier("changelog.release.\(release.version)")
    }

    private func localizedDate(_ value: String) -> String {
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: value) else { return value }

        let output = DateFormatter()
        output.locale = model.appLanguage.locale
        output.dateStyle = .medium
        return output.string(from: date)
    }
}

private struct ChangelogItemLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            configuration.icon
                .font(.system(size: 5))
                .foregroundStyle(.tertiary)
            configuration.title
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct DiagnosticsPreviewSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Redacted Diagnostics Preview", systemImage: "doc.text.magnifyingglass")
                .font(.title2.bold())
            Text("This is the exact JSON that will be written. Review it before exporting.")
                .foregroundStyle(.secondary)
            TextEditor(text: .constant(model.diagnosticsPreview))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 340)
                .accessibilityIdentifier("diagnostics.preview")
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Export…") { model.exportDiagnostics() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("diagnostics.export")
            }
        }
        .padding(24)
        .frame(width: 680, height: 520)
    }
}
