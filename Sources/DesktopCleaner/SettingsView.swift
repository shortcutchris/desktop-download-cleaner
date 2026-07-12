import DesktopCleanerCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            SourceSettingsView()
                .tabItem { Label("Sources", systemImage: "folder") }
            ReviewSettingsView()
                .tabItem { Label("Review", systemImage: "shippingbox") }
            RenamingSettingsView()
                .tabItem { Label("Renaming", systemImage: "textformat") }
            RuleSettingsView()
                .tabItem { Label("Rules", systemImage: "list.bullet.rectangle") }
            AISettingsView()
                .tabItem { Label("AI", systemImage: "sparkles") }
            UpdateSettingsView()
                .tabItem { Label("Updates", systemImage: "arrow.triangle.2.circlepath") }
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

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))
            Toggle("Show notifications when staging completes", isOn: $model.notificationsEnabled)
            Toggle("Show menu bar item", isOn: $model.menuBarEnabled)
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
                LabeledContent("Current", value: model.reviewRoot?.displayName ?? "Not selected")
                Button("Choose Review Folder…") { model.chooseReviewRoot() }
            }
            Section("Staging") {
                Picker("Default operation", selection: $model.operation) {
                    Text("Move").tag(FileOperation.move)
                    Text("Copy").tag(FileOperation.copy)
                }
                Picker("Session history", selection: $model.sessionHistoryRetention) {
                    ForEach(SessionHistoryRetention.allCases, id: \.self) { policy in
                        Text(policy.displayName).tag(policy)
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
                    Text(style.displayName).tag(style)
                }
            }
            Picker("Detected dates", selection: $model.filenameDateStyle) {
                ForEach(FilenameDateStyle.allCases, id: \.self) { style in
                    Text(style.displayName).tag(style)
                }
            }
            Picker("Collision suffix", selection: $model.collisionSuffixStyle) {
                ForEach(CollisionSuffixStyle.allCases, id: \.self) { style in
                    Text(style.displayName).tag(style)
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
                            .accessibilityLabel("Enable \(source.displayName)")
                            Spacer()
                            Button("Remove", role: .destructive) { model.removeSource(source) }
                        }
                        Stepper(
                            "Scan depth: \(source.scanDepth == 0 ? "direct children" : "\(source.scanDepth) level(s)")",
                            value: Binding(
                                get: { source.scanDepth },
                                set: { model.updateSource(id: source.id, scanDepth: $0) }
                            ),
                            in: 0...5
                        )
                        .font(.caption)
                        .accessibilityLabel("Scan depth for \(source.displayName)")
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
                        ? "Include files of any age"
                        : "Only files at least \(model.minimumAgeDays) day(s) old",
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
                LabeledContent("Current", value: model.reviewRoot?.displayName ?? "Not selected")
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
                Label("\(model.ruleConflicts.count) conflicting rule pair(s). The first enabled rule wins.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.callout)
            }
            List {
                ForEach($model.rules) { $rule in
                    HStack(spacing: 10) {
                        Toggle("", isOn: $rule.isEnabled).labelsHidden()
                            .accessibilityLabel("Enable rule \(rule.name)")
                        TextField("Name", text: $rule.name)
                        TextField("Pattern", text: $rule.condition.pattern)
                            .frame(width: 130)
                        Picker("Category", selection: $rule.category) {
                            ForEach(ItemCategory.allCases, id: \.self) { Text($0.folderName).tag($0) }
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
                    Text(quality.displayName).tag(quality)
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
            LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development")
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
