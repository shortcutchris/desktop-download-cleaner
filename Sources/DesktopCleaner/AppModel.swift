import AppKit
import DesktopCleanerCore
import DesktopCleanerServices
import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum PlanSortOption: String, CaseIterable {
    case filename
    case newest
    case largest
    case confidence

    var displayName: String {
        switch self {
        case .filename: "Filename"
        case .newest: "Newest first"
        case .largest: "Largest first"
        case .confidence: "Confidence"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var sources: [SourceFolder] = []
    @Published var reviewRoot: SourceFolder?
    @Published var plan: CleanupPlan?
    @Published var sessions: [CleanupSession] = []
    @Published var recoverableJournals: [TransactionJournal] = []
    @Published var rules: [UserRule] = []
    @Published var exclusions: [ExclusionRule] = []
    @Published var selectedSourceID: UUID?
    @Published var selectedPlanItemIDs: Set<UUID> = [] {
        didSet {
            if !selectedPlanItemIDs.isEmpty { selectedSessionID = nil }
        }
    }
    @Published var selectedSessionID: UUID?
    @Published var selectedSessionFileURLs: [URL] = []
    @Published var selectedSettingsTab: SettingsTab = .general
    @Published var planSortOption: PlanSortOption = .filename
    @Published var searchText = ""
    @Published var isBusy = false
    @Published var isAIRequestInFlight = false
    @Published var statusMessage = "Ready"
    @Published var errorMessage: String?
    @Published var appLanguage: AppLanguage {
        didSet {
            if !isResettingAppData {
                UserDefaults.standard.set(appLanguage.rawValue, forKey: "appLanguage")
            }
            statusMessage = localized("Ready")
            aiConnectionStatus = hasAPIKey
                ? localized("API key stored securely in Keychain")
                : localized("No API key stored")
        }
    }
    @Published var operation: FileOperation {
        didSet {
            if !isResettingAppData {
                UserDefaults.standard.set(operation.rawValue, forKey: "defaultFileOperation")
            }
        }
    }
    @Published var aiPrivacyLevel: AIPrivacyLevel {
        didSet {
            if !isResettingAppData {
                UserDefaults.standard.set(aiPrivacyLevel.rawValue, forKey: "aiPrivacyLevel")
            }
        }
    }
    @Published var apiKeyDraft = ""
    @Published var hasAPIKey = false
    @Published var aiConnectionStatus = "No API key stored"
    @Published var showsAIRequestPreview = false
    @Published var showsResetConfirmation = false
    @Published var showsDiagnosticsPreview = false
    @Published var diagnosticsPreview = ""
    @Published var launchAtLogin: Bool
    @Published var automaticallyChecksForUpdates: Bool
    @Published var notificationsEnabled: Bool {
        didSet {
            if !isResettingAppData {
                UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
            }
        }
    }
    @Published var minimumAgeDays: Int {
        didSet {
            minimumAgeDays = max(0, min(minimumAgeDays, 365))
            if !isResettingAppData {
                UserDefaults.standard.set(minimumAgeDays, forKey: "minimumAgeDays")
            }
        }
    }
    @Published var menuBarEnabled: Bool {
        didSet {
            if !isResettingAppData {
                UserDefaults.standard.set(menuBarEnabled, forKey: "menuBarEnabled")
            }
        }
    }
    @Published var sessionHistoryRetention: SessionHistoryRetention {
        didSet {
            if !isResettingAppData {
                UserDefaults.standard.set(sessionHistoryRetention.rawValue, forKey: "sessionHistoryRetention")
                Task { await applySessionRetentionPolicy() }
            }
        }
    }
    @Published var filenameNamingStyle: FilenameNamingStyle {
        didSet { persist(filenameNamingStyle.rawValue, key: "filenameNamingStyle") }
    }
    @Published var filenameDateStyle: FilenameDateStyle {
        didSet { persist(filenameDateStyle.rawValue, key: "filenameDateStyle") }
    }
    @Published var collisionSuffixStyle: CollisionSuffixStyle {
        didSet { persist(collisionSuffixStyle.rawValue, key: "collisionSuffixStyle") }
    }
    @Published var aiQualityPreference: AIQualityPreference {
        didSet { persist(aiQualityPreference.rawValue, key: "aiQualityPreference") }
    }

    private let folderAccess = FolderAccessService()
    private let cleanupService = LocalCleanupService()
    private let journalStore = TransactionJournalStore()
    private let sessionStore = SessionStore()
    private let planStore = PlanStore()
    private let ruleStore = RuleStore()
    private let exclusionStore = ExclusionStore()
    private let openAIService: any AIProposalServicing = OpenAIProposalService()
    private let launchAtLoginService = LaunchAtLoginService()
    private let notificationService = NotificationService()
    private let appDataResetService = AppDataResetService()
    private let diagnosticsExportService = DiagnosticsExportService()
    private let updateService: UpdateService
    private lazy var transactionExecutor = TransactionExecutor(journalStore: journalStore)
    private var accessSessions: [UUID: FolderAccessSession] = [:]
    private var directURLs: [UUID: URL] = [:]
    private var directReviewRootURL: URL?
    private var isResettingAppData = false
    private var aiRequestTask: Task<Void, Never>?
    private var planPersistenceTask: Task<Void, Never>?
    private var diagnosticsExportData: Data?

    init() {
        let processInfo = ProcessInfo.processInfo
        let isUITesting = processInfo.arguments.contains("--ui-testing")
            || processInfo.environment["DESKTOP_CLEANER_UI_TESTING"] == "1"
        updateService = UpdateService(isEnabled: !isUITesting)
        appLanguage = AppLanguage(
            rawValue: processInfo.environment["DESKTOP_CLEANER_LANGUAGE"]
                ?? UserDefaults.standard.string(forKey: "appLanguage")
                ?? ""
        ) ?? .system
        operation = FileOperation(rawValue: UserDefaults.standard.string(forKey: "defaultFileOperation") ?? "") ?? .move
        aiPrivacyLevel = AIPrivacyLevel(rawValue: UserDefaults.standard.string(forKey: "aiPrivacyLevel") ?? "") ?? .off
        launchAtLogin = launchAtLoginService.isEnabled
        automaticallyChecksForUpdates = updateService.automaticallyChecksForUpdates
        notificationsEnabled = isUITesting ? false : (UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true)
        minimumAgeDays = UserDefaults.standard.integer(forKey: "minimumAgeDays")
        menuBarEnabled = UserDefaults.standard.object(forKey: "menuBarEnabled") as? Bool ?? true
        sessionHistoryRetention = SessionHistoryRetention(
            rawValue: UserDefaults.standard.string(forKey: "sessionHistoryRetention") ?? ""
        ) ?? .forever
        filenameNamingStyle = FilenameNamingStyle(
            rawValue: UserDefaults.standard.string(forKey: "filenameNamingStyle") ?? ""
        ) ?? .natural
        filenameDateStyle = FilenameDateStyle(
            rawValue: UserDefaults.standard.string(forKey: "filenameDateStyle") ?? ""
        ) ?? .preserve
        collisionSuffixStyle = CollisionSuffixStyle(
            rawValue: UserDefaults.standard.string(forKey: "collisionSuffixStyle") ?? ""
        ) ?? .enDash
        aiQualityPreference = AIQualityPreference(
            rawValue: UserDefaults.standard.string(forKey: "aiQualityPreference") ?? ""
        ) ?? .fast
        statusMessage = localized("Ready")
        aiConnectionStatus = localized("No API key stored")
        if !isUITesting {
            Task { await loadPersistedState() }
        }
    }

    var needsOnboarding: Bool { sources.isEmpty }
    var canCheckForUpdates: Bool { updateService.canCheckForUpdates }
    var selectedSource: SourceFolder? { sources.first { $0.id == selectedSourceID } }
    var selectedSession: CleanupSession? { sessions.first { $0.id == selectedSessionID } }
    var selectedPlanItemID: UUID? { selectedPlanItemIDs.count == 1 ? selectedPlanItemIDs.first : nil }
    var selectedPlanItem: PlanItem? { plan?.items.first { $0.id == selectedPlanItemID } }
    var selectedPlanItems: [PlanItem] {
        plan?.items.filter { selectedPlanItemIDs.contains($0.id) } ?? []
    }
    var approvedCount: Int { plan?.items.filter { $0.approvalState == .approved }.count ?? 0 }
    var pendingCount: Int { plan?.items.filter { $0.approvalState == .pending }.count ?? 0 }
    var estimatedAIInputTokens: Int { max(120, aiEligibleItems.count * 90) }
    var aiEligibleItems: [PlanItem] {
        plan?.items.filter { !$0.classification.isSensitive && !$0.classification.isExcluded } ?? []
    }
    var ruleConflicts: [RuleConflict] { RuleEngine(rules: rules).conflicts() }
    var renamePreferences: RenamePreferences {
        RenamePreferences(
            namingStyle: filenameNamingStyle,
            dateStyle: filenameDateStyle,
            collisionSuffixStyle: collisionSuffixStyle
        )
    }
    func localized(_ key: String, _ arguments: CVarArg...) -> String {
        L10n.string(key, language: appLanguage, arguments: arguments)
    }

    func localizedCategory(_ category: ItemCategory) -> String {
        localized(category.folderName)
    }

    func localizedClassificationReason(_ reason: String) -> String {
        let exclusionPrefix = "Matches exclusion rule "
        if reason.hasPrefix(exclusionPrefix) {
            return localized("Matches exclusion rule %@", String(reason.dropFirst(exclusionPrefix.count)))
        }
        let rulePrefix = "Matched user rule: "
        if reason.hasPrefix(rulePrefix) {
            return localized("Matched user rule: %@", String(reason.dropFirst(rulePrefix.count)))
        }
        let aiPrefix = "AI: "
        if reason.hasPrefix(aiPrefix) {
            return localized("AI: %@", String(reason.dropFirst(aiPrefix.count)))
        }
        return localized(reason)
    }

    func localizedTransactionState(_ state: TransactionState) -> String {
        localized(state.rawValue.capitalized)
    }
    var filteredPlanItems: [PlanItem] {
        guard var items = plan?.items else { return [] }
        if !searchText.isEmpty {
            items = items.filter {
                $0.scannedItem.filename.localizedCaseInsensitiveContains(searchText)
                    || $0.proposedFilename.localizedCaseInsensitiveContains(searchText)
                    || localizedCategory($0.classification.category).localizedCaseInsensitiveContains(searchText)
            }
        }
        return items.sorted { lhs, rhs in
            switch planSortOption {
            case .filename:
                return lhs.proposedFilename.localizedStandardCompare(rhs.proposedFilename) == .orderedAscending
            case .newest:
                return (lhs.scannedItem.modificationDate ?? .distantPast) > (rhs.scannedItem.modificationDate ?? .distantPast)
            case .largest:
                return lhs.scannedItem.size == rhs.scannedItem.size
                    ? lhs.proposedFilename < rhs.proposedFilename
                    : lhs.scannedItem.size > rhs.scannedItem.size
            case .confidence:
                let lhsRank = Self.confidenceRank(lhs.classification.confidence)
                let rhsRank = Self.confidenceRank(rhs.classification.confidence)
                return lhsRank == rhsRank
                    ? lhs.proposedFilename.localizedStandardCompare(rhs.proposedFilename) == .orderedAscending
                    : lhsRank > rhsRank
            }
        }
    }

    func chooseSourceFolder(startingAt suggestedURL: URL? = nil) {
        guard let url = chooseFolder(
            prompt: localized("Choose a folder to organize"),
            startingAt: suggestedURL
        ) else { return }
        Task {
            do {
                let folder = try await folderAccess.authorize(url, kind: .source)
                sources.append(folder)
                selectedSourceID = folder.id
                statusMessage = localized("Source added")
                if reviewRoot == nil { chooseReviewRoot() }
            } catch { present(error) }
        }
    }

    func chooseDesktopFolder() {
        chooseSourceFolder(startingAt: FolderAccessService.suggestedDesktopURL)
    }

    func chooseDownloadsFolder() {
        chooseSourceFolder(startingAt: FolderAccessService.suggestedDownloadsURL)
    }

    func chooseReviewRoot() {
        guard let url = chooseFolder(prompt: localized("Choose a visible review folder")) else { return }
        Task {
            do {
                let folder = try await folderAccess.authorize(url, kind: .reviewRoot)
                reviewRoot = folder
                statusMessage = localized("Review folder: %@", folder.displayName)
            } catch { present(error) }
        }
    }

    func useDemoFiles() {
        setBusy(localized("Preparing safe demo files…"))
        Task {
            do {
                let fixture = try DemoFixtureService().create()
                sources = [fixture.source]
                selectedSourceID = fixture.source.id
                directURLs[fixture.source.id] = fixture.sourceURL
                directReviewRootURL = fixture.reviewRootURL
                reviewRoot = SourceFolder(displayName: "Tidy Review", kind: .reviewRoot)
                finishBusy(localized("Demo ready"))
                scanSelectedSource()
            } catch {
                finishBusy(localized("Demo failed"))
                present(error)
            }
        }
    }

    func scanSelectedSource() {
        guard let source = selectedSource, source.isEnabled else {
            statusMessage = localized("Enable the selected source before scanning")
            return
        }
        setBusy(localized("Scanning %@…", source.displayName))
        Task {
            do {
                let sourceURL = try await accessibleURL(for: source)
                let sessionName = Self.sessionNameFormatter.string(from: Date())
                let newPlan = try await cleanupService.scanAndPlan(
                    source: source,
                    at: sourceURL,
                    sessionDirectoryName: sessionName,
                    rules: rules,
                    exclusions: exclusions,
                    minimumAgeDays: minimumAgeDays,
                    renamePreferences: renamePreferences
                )
                plan = newPlan
                selectedPlanItemIDs = Set(newPlan.items.first.map { [$0.id] } ?? [])
                persistCurrentPlan()
                finishBusy(localized("%@ proposals ready", String(newPlan.items.count)))
            } catch {
                finishBusy(localized("Scan failed"))
                present(error)
            }
        }
    }

    func toggleApproval(for id: UUID) {
        guard let index = plan?.items.firstIndex(where: { $0.id == id }) else { return }
        plan?.items[index].approvalState = plan?.items[index].approvalState == .approved ? .pending : .approved
        persistCurrentPlan()
    }

    func approveSafeItems() {
        guard var current = plan else { return }
        for index in current.items.indices {
            let item = current.items[index]
            if item.classification.confidence != .low && !item.classification.isSensitive {
                current.items[index].approvalState = .approved
            }
        }
        plan = current
        persistCurrentPlan()
    }

    func selectAllVisibleItems() {
        selectedPlanItemIDs = Set(filteredPlanItems.map(\.id))
        statusMessage = localized("Selected %@ visible proposals", String(selectedPlanItemIDs.count))
    }

    func approveSelectedItems() {
        guard var current = plan else { return }
        var approved = 0
        for index in current.items.indices where selectedPlanItemIDs.contains(current.items[index].id) {
            let item = current.items[index]
            guard item.classification.confidence != .low, !item.classification.isSensitive else { continue }
            current.items[index].approvalState = .approved
            approved += 1
        }
        plan = current
        persistCurrentPlan()
        statusMessage = localized("Approved %@ selected safe proposals", String(approved))
    }

    func rejectSelectedItems() {
        guard var current = plan else { return }
        for index in current.items.indices where selectedPlanItemIDs.contains(current.items[index].id) {
            current.items[index].approvalState = .rejected
        }
        plan = current
        persistCurrentPlan()
        statusMessage = localized("Rejected %@ selected proposals", String(selectedPlanItemIDs.count))
    }

    func rejectSelected() {
        guard let id = selectedPlanItemID,
              let index = plan?.items.firstIndex(where: { $0.id == id }) else { return }
        plan?.items[index].approvalState = .rejected
        persistCurrentPlan()
    }

    func updateSelectedFilename(_ value: String) {
        guard let id = selectedPlanItemID,
              let index = plan?.items.firstIndex(where: { $0.id == id }) else { return }
        let item = plan!.items[index]
        let sanitized = FilenameSanitizer(preferences: renamePreferences).filename(
            basename: URL(fileURLWithPath: value).deletingPathExtension().lastPathComponent,
            pathExtension: item.scannedItem.pathExtension
        )
        plan?.items[index].proposedFilename = sanitized
        let components = item.relativeDestination.split(separator: "/").dropLast()
        plan?.items[index].relativeDestination = (components.map(String.init) + [sanitized]).joined(separator: "/")
        persistCurrentPlan()
    }

    func updateSelectedCategory(_ category: ItemCategory) {
        guard let id = selectedPlanItemID,
              let index = plan?.items.firstIndex(where: { $0.id == id }) else { return }
        plan?.items[index].classification = Classification(
            category: category,
            confidence: plan!.items[index].classification.confidence,
            reason: "Edited by user",
            isExcluded: false,
            isSensitive: plan!.items[index].classification.isSensitive
        )
        let item = plan!.items[index]
        plan?.items[index].relativeDestination = [
            plan!.sessionDirectoryName, category.folderName, item.proposedFilename
        ].joined(separator: "/")
        persistCurrentPlan()
    }

    func stageApprovedItems() {
        guard let currentPlan = plan, approvedCount > 0, let source = selectedSource else { return }
        setBusy(localized("Preflighting %@ approved items…", String(approvedCount)))
        Task {
            do {
                let sourceURL = try await accessibleURL(for: source)
                let reviewURL = try await accessibleReviewRootURL()
                let journal = try await transactionExecutor.stage(
                    plan: currentPlan,
                    sourceRoots: [source.id: sourceURL],
                    reviewRoot: reviewURL,
                    operation: operation
                )
                let session = CleanupSession(
                    planID: currentPlan.id,
                    journalID: journal.id,
                    sessionDirectoryName: currentPlan.sessionDirectoryName,
                    state: journal.state,
                    itemCount: journal.steps.count
                )
                try await sessionStore.upsert(session)
                sessions.insert(session, at: 0)
                plan = nil
                planPersistenceTask?.cancel()
                try await planStore.clear()
                selectSession(session)
                finishBusy(localized("Staged %@ items safely", String(journal.steps.count)))
                if notificationsEnabled {
                    _ = try? await notificationService.requestAuthorization()
                    try? await notificationService.notify(
                        title: localized("Cleanup session staged"),
                        body: localized(
                            "%@ items are ready in %@.",
                            String(journal.steps.count),
                            currentPlan.sessionDirectoryName
                        )
                    )
                }
            } catch {
                finishBusy(localized("Staging failed"))
                present(error)
            }
        }
    }

    func saveAPIKey() {
        let key = apiKeyDraft
        guard !key.isEmpty else { return }
        Task {
            do {
                try await openAIService.saveAPIKey(key)
                apiKeyDraft = ""
                hasAPIKey = true
                aiConnectionStatus = localized("API key stored securely in Keychain")
            } catch { present(error) }
        }
    }

    func deleteAPIKey() {
        Task {
            do {
                try await openAIService.deleteAPIKey()
                apiKeyDraft = ""
                hasAPIKey = false
                aiPrivacyLevel = .off
                aiConnectionStatus = localized("No API key stored")
            } catch { present(error) }
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLoginService.setEnabled(enabled)
            launchAtLogin = launchAtLoginService.isEnabled
        } catch { present(error) }
    }

    func testAIConnection() {
        setBusy(localized("Testing OpenAI connection…"))
        Task {
            do {
                try await openAIService.testConnection()
                aiConnectionStatus = localized("Connection successful")
                finishBusy(localized("OpenAI connection ready"))
            } catch {
                aiConnectionStatus = localized("Connection failed")
                finishBusy(localized("OpenAI connection failed"))
                present(error)
            }
        }
    }

    func prepareAIRequest() {
        guard aiPrivacyLevel == .metadataOnly, hasAPIKey, !aiEligibleItems.isEmpty else { return }
        showsAIRequestPreview = true
    }

    func confirmAIRequest() {
        guard !isAIRequestInFlight else { return }
        let eligible = aiEligibleItems.map(\.scannedItem)
        showsAIRequestPreview = false
        isAIRequestInFlight = true
        setBusy(localized("Requesting AI metadata proposals for %@ items…", String(eligible.count)))
        aiRequestTask = Task { [weak self] in
            guard let self else { return }
            do {
                let proposals = try await openAIService.proposeMetadata(
                    for: eligible,
                    quality: aiQualityPreference,
                    responseLanguage: appLanguage.aiLanguageName
                )
                try Task.checkCancellation()
                applyAIProposals(proposals)
                finishBusy(localized("Applied %@ validated AI proposals", String(proposals.count)))
            } catch is CancellationError {
                finishBusy(localized("AI request cancelled; local plan preserved"))
            } catch {
                finishBusy(localized("AI proposals unavailable; local plan preserved"))
                present(error)
            }
            isAIRequestInFlight = false
            aiRequestTask = nil
        }
    }

    func cancelAIRequest() {
        guard isAIRequestInFlight else { return }
        aiRequestTask?.cancel()
        statusMessage = localized("Cancelling AI request…")
    }

    func undo(_ session: CleanupSession) {
        setBusy(localized("Undoing %@ items…", String(session.itemCount)))
        Task {
            do {
                try await prepareSecurityScopedAccessForRollback()
                let journal = try await transactionExecutor.rollback(journalID: session.journalID)
                try await sessionStore.updateState(journalID: session.journalID, state: journal.state)
                if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                    sessions[index].state = journal.state
                }
                if selectedSessionID == session.id { selectedSessionFileURLs = [] }
                finishBusy(localized("Session restored"))
            } catch {
                finishBusy(localized("Undo needs attention"))
                present(error)
            }
        }
    }

    func recover(_ journal: TransactionJournal) {
        setBusy(localized("Recovering interrupted session…"))
        Task {
            do {
                try await prepareSecurityScopedAccessForRollback()
                let recovered = try await transactionExecutor.rollback(journalID: journal.id)
                recoverableJournals.removeAll { $0.id == journal.id }
                try await sessionStore.updateState(journalID: journal.id, state: recovered.state)
                finishBusy(localized("Interrupted session rolled back safely"))
            } catch {
                finishBusy(localized("Recovery needs attention"))
                present(error)
            }
        }
    }

    func retain(_ session: CleanupSession) {
        setBusy(localized("Keeping organized session as final…"))
        Task {
            do {
                let journal = try await transactionExecutor.retain(journalID: session.journalID)
                try await sessionStore.updateState(journalID: session.journalID, state: journal.state)
                if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                    sessions[index].state = journal.state
                }
                finishBusy(localized("Session kept as final"))
            } catch {
                finishBusy(localized("Session could not be finalized"))
                present(error)
            }
        }
    }

    func selectSession(_ session: CleanupSession) {
        selectedSessionID = session.id
        selectedPlanItemIDs = []
        selectedSessionFileURLs = []
        Task {
            do {
                _ = try await accessibleReviewRootURL()
                selectedSessionFileURLs = try await transactionExecutor.existingStagedFileURLs(
                    journalID: session.journalID
                )
            } catch {
                if [.staged, .retained, .failed].contains(session.state) { present(error) }
            }
        }
    }

    func reveal(_ session: CleanupSession) {
        Task {
            do {
                let root = try await accessibleReviewRootURL()
                NSWorkspace.shared.activateFileViewerSelecting([
                    root.appendingPathComponent(session.sessionDirectoryName, isDirectory: true)
                ])
            } catch { present(error) }
        }
    }

    func quickLookSelected() {
        guard let item = selectedPlanItem, let source = selectedSource else { return }
        Task {
            do {
                let root = try await accessibleURL(for: source)
                QuickLookPresenter.shared.preview(root.appendingPathComponent(item.scannedItem.relativePath))
            } catch { present(error) }
        }
    }

    func addRule() {
        let rule = UserRule(
            name: localized("New rule"),
            order: rules.count,
            condition: RuleCondition(kind: .filename, pattern: "*"),
            category: .documents
        )
        rules.append(rule)
        saveRules()
    }

    func createRuleFromSelectedItem() {
        guard let item = selectedPlanItem else { return }
        rules.append(UserRule(
            name: localized("Organize %@", item.scannedItem.filename),
            order: rules.count,
            condition: RuleCondition(kind: .filename, pattern: item.scannedItem.filename),
            category: item.classification.category
        ))
        saveRules()
        statusMessage = localized("Rule created — review it in Settings")
    }

    func addExclusion() {
        exclusions.append(ExclusionRule(kind: .filename, pattern: "*.tmp"))
        saveExclusions()
    }

    func excludeSelectedFilename() {
        guard let item = selectedPlanItem else { return }
        let rule = ExclusionRule(kind: .filename, pattern: item.scannedItem.filename)
        guard !exclusions.contains(where: { $0.kind == rule.kind && $0.pattern == rule.pattern }) else { return }
        exclusions.append(rule)
        saveExclusions()
        plan?.items.removeAll { $0.id == item.id }
        selectedPlanItemIDs = Set(plan?.items.first.map { [$0.id] } ?? [])
        persistCurrentPlan()
        statusMessage = localized("Excluded %@ from future plans", item.scannedItem.filename)
    }

    func deleteExclusions(at offsets: IndexSet) {
        exclusions.remove(atOffsets: offsets)
        saveExclusions()
    }

    func saveExclusions() {
        let current = exclusions.filter { !$0.pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        Task {
            do { try await exclusionStore.save(current) }
            catch { present(error) }
        }
    }

    func updateSource(id: UUID, isEnabled: Bool? = nil, scanDepth: Int? = nil) {
        guard let index = sources.firstIndex(where: { $0.id == id }) else { return }
        if let isEnabled { sources[index].isEnabled = isEnabled }
        if let scanDepth { sources[index].scanDepth = max(0, min(scanDepth, 5)) }
        let updated = sources[index]
        guard directURLs[id] == nil else { return }
        Task {
            do { try await folderAccess.update(updated) }
            catch { present(error) }
        }
    }

    func showMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.windows.first(where: {
            $0.identifier?.rawValue.contains("AppWindow") == true
        })?.makeKeyAndOrderFront(nil)
    }

    func prepareDiagnosticsExport() {
        do {
            let data = try diagnosticsExportService.reportData(for: diagnosticsInput())
            diagnosticsExportData = data
            diagnosticsPreview = String(decoding: data, as: UTF8.self)
            showsDiagnosticsPreview = true
        } catch { present(error) }
    }

    func exportDiagnostics() {
        guard let data = diagnosticsExportData else { return }
        let panel = NSSavePanel()
        panel.title = localized("Export Redacted Desktop Cleaner Diagnostics")
        panel.nameFieldStringValue = "Desktop Cleaner Diagnostics.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try diagnosticsExportService.export(data, to: url)
            showsDiagnosticsPreview = false
            statusMessage = localized("Redacted diagnostics exported")
        } catch { present(error) }
    }

    func resetAllAppData() {
        Task {
            do {
                isResettingAppData = true
                defer { isResettingAppData = false }
                planPersistenceTask?.cancel()
                try await openAIService.deleteAPIKey()
                try launchAtLoginService.setEnabled(false)
                try await appDataResetService.resetMetadataAndSettings()
                sources = []
                reviewRoot = nil
                plan = nil
                sessions = []
                selectedPlanItemIDs = []
                selectedSessionID = nil
                selectedSessionFileURLs = []
                rules = []
                exclusions = []
                recoverableJournals = []
                accessSessions = [:]
                directURLs = [:]
                directReviewRootURL = nil
                hasAPIKey = false
                apiKeyDraft = ""
                aiPrivacyLevel = .off
                operation = .move
                notificationsEnabled = true
                minimumAgeDays = 0
                menuBarEnabled = true
                sessionHistoryRetention = .forever
                filenameNamingStyle = .natural
                filenameDateStyle = .preserve
                collisionSuffixStyle = .enDash
                aiQualityPreference = .fast
                appLanguage = .system
                launchAtLogin = false
                setAutomaticallyChecksForUpdates(false)
                aiConnectionStatus = localized("No API key stored")
                statusMessage = localized("All app data deleted; user files were untouched")
            } catch { present(error) }
        }
    }

    func checkForUpdates() {
        statusMessage = updateService.checkForUpdates()
            ? localized("Checking for updates…")
            : localized("Update checker is starting; try again in a moment")
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        updateService.setAutomaticallyChecksForUpdates(enabled)
        automaticallyChecksForUpdates = updateService.automaticallyChecksForUpdates
    }

    func deleteRules(at offsets: IndexSet) {
        rules.remove(atOffsets: offsets)
        saveRules()
    }

    func saveRules() {
        let current = rules
        Task {
            do { try await ruleStore.save(current) }
            catch { present(error) }
        }
    }

    func moveRules(from offsets: IndexSet, to destination: Int) {
        rules.move(fromOffsets: offsets, toOffset: destination)
        for index in rules.indices { rules[index].order = index }
        saveRules()
    }

    func importRules() {
        let panel = NSOpenPanel()
        panel.title = localized("Import Desktop Cleaner Rules")
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do {
                rules = try await ruleStore.importRules(from: url)
                saveRules()
                statusMessage = localized("Imported %@ rules", String(rules.count))
            } catch { present(error) }
        }
    }

    func exportRules() {
        let panel = NSSavePanel()
        panel.title = localized("Export Desktop Cleaner Rules")
        panel.nameFieldStringValue = "Desktop Cleaner Rules.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let current = rules
        Task {
            do {
                try await ruleStore.export(current, to: url)
                statusMessage = localized("Rules exported")
            } catch { present(error) }
        }
    }

    func removeSource(_ source: SourceFolder) {
        Task {
            do {
                try await folderAccess.removeAuthorization(for: source.id)
                accessSessions[source.id] = nil
                directURLs[source.id] = nil
                sources.removeAll { $0.id == source.id }
                if selectedSourceID == source.id { selectedSourceID = sources.first?.id }
            } catch { present(error) }
        }
    }

    private func loadPersistedState() async {
        do {
            let folders = try await folderAccess.authorizedFolders()
            sources = folders.filter { $0.kind == .source }
            reviewRoot = folders.last { $0.kind == .reviewRoot }
            selectedSourceID = sources.first?.id
            if let savedPlan = try await planStore.load(),
               let savedSourceID = savedPlan.items.first?.scannedItem.sourceID,
               sources.contains(where: { $0.id == savedSourceID }) {
                plan = savedPlan
                selectedSourceID = savedSourceID
                selectedPlanItemIDs = Set(savedPlan.items.first.map { [$0.id] } ?? [])
            }
            await applySessionRetentionPolicy()
            sessions = try await sessionStore.load()
            rules = try await ruleStore.load()
            exclusions = try await exclusionStore.load()
            hasAPIKey = try await openAIService.hasAPIKey()
            aiConnectionStatus = hasAPIKey
                ? localized("API key stored securely in Keychain")
                : localized("No API key stored")
            let recoverable = try await transactionExecutor.recoverableJournals()
            recoverableJournals = recoverable
            if !recoverable.isEmpty {
                statusMessage = localized("%@ session(s) need recovery", String(recoverable.count))
            }
        } catch { present(error) }
    }

    private func accessibleURL(for source: SourceFolder) async throws -> URL {
        if let url = directURLs[source.id] { return url }
        if let session = accessSessions[source.id] { return session.url }
        let session = try await folderAccess.beginAccess(to: source.id)
        accessSessions[source.id] = session
        return session.url
    }

    private func applyAIProposals(_ proposals: [AIProposal]) {
        guard var current = plan else { return }
        for proposal in proposals {
            guard let index = current.items.firstIndex(where: { $0.scannedItem.id == proposal.itemID }),
                  !current.items[index].classification.isSensitive else { continue }
            let original = current.items[index]
            let filename = FilenameSanitizer(preferences: renamePreferences).filename(
                basename: proposal.suggestedBasename,
                pathExtension: original.scannedItem.pathExtension
            )
            current.items[index].classification = Classification(
                category: proposal.category,
                confidence: proposal.confidence,
                reason: "AI: \(proposal.reason)"
            )
            current.items[index].proposedFilename = filename
            current.items[index].relativeDestination = [
                current.sessionDirectoryName, proposal.category.folderName, filename
            ].joined(separator: "/")
            current.items[index].approvalState = .pending
        }
        plan = current
        persistCurrentPlan()
    }

    private func accessibleReviewRootURL() async throws -> URL {
        if let directReviewRootURL { return directReviewRootURL }
        guard let reviewRoot else { throw FolderAccessError.authorizationNotFound }
        if let session = accessSessions[reviewRoot.id] { return session.url }
        let session = try await folderAccess.beginAccess(to: reviewRoot.id)
        accessSessions[reviewRoot.id] = session
        return session.url
    }

    private func prepareSecurityScopedAccessForRollback() async throws {
        for source in sources where directURLs[source.id] == nil {
            _ = try await accessibleURL(for: source)
        }
        _ = try await accessibleReviewRootURL()
    }

    private func chooseFolder(prompt: String, startingAt suggestedURL: URL? = nil) -> URL? {
        let panel = NSOpenPanel()
        panel.title = prompt
        panel.prompt = localized("Choose")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = suggestedURL
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func setBusy(_ message: String) {
        isBusy = true
        statusMessage = message
    }

    private func finishBusy(_ message: String) {
        isBusy = false
        statusMessage = message
    }

    private func present(_ error: Error) {
        if let urlError = error as? URLError {
            errorMessage = localized("Network connection failed: %@", urlError.localizedDescription)
        } else if let openAIError = error as? OpenAIServiceError {
            switch openAIError {
            case .missingAPIKey:
                errorMessage = localized("No OpenAI API key is stored.")
            case .invalidResponse:
                errorMessage = localized("OpenAI returned an unreadable response. The local plan was preserved.")
            case .refusal(let message):
                errorMessage = localized("OpenAI declined the request: %@", message)
            case .requestFailed(let statusCode, let message):
                errorMessage = localized(
                    "OpenAI request failed (%@): %@",
                    String(statusCode),
                    message
                )
            }
        } else {
            errorMessage = localized(error.localizedDescription)
        }
    }

    private func applySessionRetentionPolicy() async {
        guard let days = sessionHistoryRetention.dayCount,
              let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return }
        do {
            let removedJournalIDs = try await sessionStore.pruneFinalized(before: cutoff)
            try await journalStore.removeFinalized(ids: removedJournalIDs)
            sessions = try await sessionStore.load()
        } catch { present(error) }
    }

    private func diagnosticsInput() -> DiagnosticsInput {
        let sessionCounts = Dictionary(grouping: sessions, by: { $0.state.rawValue })
            .mapValues(\.count)
        return DiagnosticsInput(
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development",
            buildNumber: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Development",
            sourceCount: sources.count,
            sessionStateCounts: sessionCounts,
            ruleCount: rules.count,
            exclusionCount: exclusions.count,
            hasAPIKey: hasAPIKey,
            aiPrivacyLevel: aiPrivacyLevel.rawValue,
            aiQuality: aiQualityPreference,
            operation: operation,
            minimumAgeDays: minimumAgeDays,
            menuBarEnabled: menuBarEnabled,
            renamePreferences: renamePreferences,
            sessionRetention: sessionHistoryRetention
        )
    }

    private func persist(_ value: String, key: String) {
        if !isResettingAppData { UserDefaults.standard.set(value, forKey: key) }
    }

    private func persistCurrentPlan() {
        guard let snapshot = plan else { return }
        planPersistenceTask?.cancel()
        planPersistenceTask = Task { [weak self] in
            guard let self else { return }
            do {
                try Task.checkCancellation()
                try await planStore.save(snapshot)
            } catch is CancellationError {
                return
            } catch { present(error) }
        }
    }

    private static func confidenceRank(_ confidence: ClassificationConfidence) -> Int {
        switch confidence {
        case .high: 3
        case .medium: 2
        case .low: 1
        }
    }

    private static let sessionNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH-mm"
        return formatter
    }()
}
