import AppKit
import DesktopCleanerCore
import SwiftUI

struct MainView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.needsOnboarding {
                WelcomeView()
            } else {
                WorkspaceView()
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            StatusBar()
        }
        .alert("Desktop Cleaner", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "Unknown error")
        }
        .sheet(isPresented: $model.showsAIRequestPreview) {
            AIRequestPreviewSheet()
                .environmentObject(model)
        }
    }
}

private struct WelcomeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color.accentColor.opacity(0.11)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            HStack(spacing: 54) {
                VStack(alignment: .leading, spacing: 22) {
                    Label("Desktop Cleaner", systemImage: "sparkles.rectangle.stack.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.tint)
                    Text("Turn clutter into a plan — before anything moves.")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .frame(maxWidth: 540, alignment: .leading)
                    Text("Review deterministic categories, approve only what you want, stage changes in a visible folder, and undo the complete session.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 530, alignment: .leading)

                    HStack(spacing: 12) {
                        Button("Desktop…") { model.chooseDesktopFolder() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .accessibilityIdentifier("welcome.chooseSource")
                        Button("Downloads…") { model.chooseDownloadsFolder() }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        Button("Other…") { model.chooseSourceFolder() }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        Button("Try Safe Demo") { model.useDemoFiles() }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .accessibilityIdentifier("welcome.tryDemo")
                    }
                    Label("Scanning and planning are read-only. Nothing is deleted automatically.", systemImage: "lock.shield.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                SafetyStackIllustration()
                    .frame(width: 310, height: 350)
            }
            .padding(64)
        }
    }
}

private struct SafetyStackIllustration: View {
    var body: some View {
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .scaledToFit()
            .padding(12)
            .shadow(color: Color.blue.opacity(0.22), radius: 34, y: 18)
            .accessibilityHidden(true)
    }
}

private struct WorkspaceView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 270)
        } content: {
            PlanListView()
                .navigationSplitViewColumnWidth(min: 420, ideal: 560)
        } detail: {
            InspectorView()
                .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 430)
        }
        .toolbar {
            ToolbarItemGroup {
                Button { model.scanSelectedSource() } label: {
                    Label("Scan", systemImage: "arrow.clockwise")
                }
                .disabled(model.isBusy || model.selectedSourceID == nil)
                .accessibilityIdentifier("toolbar.scan")

                Button { model.approveSafeItems() } label: {
                    Label("Approve Safe", systemImage: "checkmark.circle")
                }
                .disabled(model.plan == nil)
                .accessibilityIdentifier("toolbar.approveSafe")

                Menu {
                    Button("Select All Visible") { model.selectAllVisibleItems() }
                    Divider()
                    Button("Approve Selected Safe Items") { model.approveSelectedItems() }
                        .disabled(model.selectedPlanItemIDs.isEmpty)
                    Button("Reject Selected Items", role: .destructive) { model.rejectSelectedItems() }
                        .disabled(model.selectedPlanItemIDs.isEmpty)
                } label: {
                    Label("Selected \(model.selectedPlanItemIDs.count)", systemImage: "checklist")
                }
                .disabled(model.plan == nil)
                .accessibilityIdentifier("toolbar.selection")

                Menu {
                    Picker("Sort proposals", selection: $model.planSortOption) {
                        ForEach(PlanSortOption.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                .disabled(model.plan == nil)
                .accessibilityIdentifier("toolbar.sort")

                if model.isAIRequestInFlight {
                    Button(role: .cancel) { model.cancelAIRequest() } label: {
                        Label("Cancel AI", systemImage: "stop.circle.fill")
                    }
                    .accessibilityIdentifier("toolbar.cancelAI")
                } else {
                    Button { model.prepareAIRequest() } label: {
                        Label("AI Proposals", systemImage: "sparkles")
                    }
                    .disabled(
                        model.aiPrivacyLevel != .metadataOnly
                            || !model.hasAPIKey
                            || model.aiEligibleItems.isEmpty
                            || model.isBusy
                    )
                    .accessibilityIdentifier("toolbar.aiProposals")
                }

                Button { model.stageApprovedItems() } label: {
                    Label("Stage \(model.approvedCount)", systemImage: "shippingbox.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.approvedCount == 0 || model.reviewRoot == nil || model.isBusy)
                .accessibilityIdentifier("toolbar.stage")
            }
        }
    }
}

private struct AIRequestPreviewSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Review OpenAI Request", systemImage: "eye.shield.fill")
                .font(.title2.bold())
            Text("\(model.aiEligibleItems.count) items will send metadata only. Sensitive files are excluded.")
                .font(.headline)
            GroupBox("Fields sent for each eligible item") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Filename and extension", systemImage: "textformat")
                    Label("Uniform Type Identifier", systemImage: "doc.badge.gearshape")
                    Label("Approximate size range", systemImage: "chart.bar")
                    Label("Creation and modification dates", systemImage: "calendar")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
            }
            GroupBox("Items in this request") {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 7) {
                        ForEach(model.aiEligibleItems) { item in
                            HStack {
                                Text(item.scannedItem.filename)
                                    .lineLimit(1)
                                Spacer()
                                Text("Metadata")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: min(CGFloat(model.aiEligibleItems.count * 25), 125))
            }
            Label(
                "Estimated input: about \(model.estimatedAIInputTokens) tokens. Actual API usage varies.",
                systemImage: "gauge.with.dots.needle.33percent"
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            Label("No file contents, absolute paths, previews, API commands, or approval decisions are sent.", systemImage: "lock.fill")
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Send Metadata") { model.confirmAIRequest() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("aiRequest.confirm")
            }
        }
        .padding(24)
        .frame(width: 560)
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List(selection: $model.selectedSourceID) {
            Section("Sources") {
                ForEach(model.sources) { source in
                    Label {
                        HStack {
                            Text(source.displayName)
                            if !source.isEnabled {
                                Text("Disabled")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: source.displayName.localizedCaseInsensitiveContains("download") ? "arrow.down.circle.fill" : "folder.fill")
                    }
                        .tag(source.id)
                        .opacity(source.isEnabled ? 1 : 0.55)
                        .contextMenu {
                            Button("Remove Source", role: .destructive) { model.removeSource(source) }
                        }
                }
                Button { model.chooseSourceFolder() } label: {
                    Label("Add Folder…", systemImage: "plus")
                }
                .buttonStyle(.plain)
            }

            Section("Review Folder") {
                if let reviewRoot = model.reviewRoot {
                    Label(reviewRoot.displayName, systemImage: "shippingbox.fill")
                } else {
                    Button("Choose Review Folder…") { model.chooseReviewRoot() }
                }
            }

            Section("Sessions") {
                if model.sessions.isEmpty {
                    Text("No staged sessions")
                        .foregroundStyle(.tertiary)
                }
                ForEach(model.sessions) { session in
                    Button {
                        model.selectSession(session)
                    } label: {
                        HStack {
                            Image(systemName: session.state.iconName)
                            VStack(alignment: .leading) {
                                Text(session.sessionDirectoryName)
                                    .lineLimit(1)
                                Text("\(session.itemCount) items")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Reveal in Finder") { model.reveal(session) }
                        if session.state == .staged || session.state == .failed {
                            Button("Undo Session") { model.undo(session) }
                        }
                        if session.state == .staged {
                            Button("Keep as Final") { model.retain(session) }
                        }
                    }
                }
            }

            if !model.recoverableJournals.isEmpty {
                Section("Recovery Required") {
                    ForEach(model.recoverableJournals) { journal in
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Interrupted session", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Button("Roll Back Safely") { model.recover(journal) }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Desktop Cleaner")
        .onChange(of: model.selectedSourceID) { _, _ in
            model.selectedSessionID = nil
            model.selectedSessionFileURLs = []
        }
    }
}

private struct PlanListView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.plan == nil {
                ContentUnavailableView {
                    Label("Ready to scan", systemImage: "sparkle.magnifyingglass")
                } description: {
                    Text("Select a source and create a read-only cleanup plan.")
                } actions: {
                    Button("Scan \(model.selectedSource?.displayName ?? "Source")") { model.scanSelectedSource() }
                        .buttonStyle(.borderedProminent)
                }
            } else if model.filteredPlanItems.isEmpty {
                ContentUnavailableView.search(text: model.searchText)
            } else {
                List(selection: $model.selectedPlanItemIDs) {
                    ForEach(ItemCategory.allCases, id: \.self) { category in
                        let items = model.filteredPlanItems.filter { $0.classification.category == category }
                        if !items.isEmpty {
                            Section {
                                ForEach(items) { item in
                                    PlanRow(item: item)
                                        .tag(item.id)
                                }
                            } header: {
                                HStack {
                                    Label(category.folderName, systemImage: category.iconName)
                                    Spacer()
                                    Text("\(items.count)")
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(model.plan.map { "Cleanup Plan · \($0.items.count)" } ?? "Cleanup Plan")
        .searchable(text: $model.searchText, prompt: "Search proposals")
    }
}

private struct PlanRow: View {
    @EnvironmentObject private var model: AppModel
    let item: PlanItem

    var body: some View {
        HStack(spacing: 12) {
            Button { model.toggleApproval(for: item.id) } label: {
                Image(systemName: item.approvalState == .approved ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.approvalState == .approved ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.approvalState == .approved ? "Approved" : "Not approved")
            .accessibilityIdentifier("plan.approval.\(item.id)")

            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(item.classification.category.color.opacity(0.14))
                Image(systemName: item.classification.category.iconName)
                    .foregroundStyle(item.classification.category.color)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.proposedFilename)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(item.scannedItem.filename == item.proposedFilename ? item.relativeDestination : "from \(item.scannedItem.filename)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
            ConfidenceBadge(confidence: item.classification.confidence, sensitive: item.classification.isSensitive)
        }
        .padding(.vertical, 5)
    }
}

private struct InspectorView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if let session = model.selectedSession {
            SessionInspector(session: session)
        } else if model.selectedPlanItems.count > 1 {
            MultiSelectionInspector(items: model.selectedPlanItems)
        } else if let item = model.selectedPlanItem {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(item.classification.category.color.opacity(0.12))
                        Image(systemName: item.classification.category.iconName)
                            .font(.system(size: 54))
                            .foregroundStyle(item.classification.category.color)
                    }
                    .frame(height: 150)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Proposed name").font(.caption).foregroundStyle(.secondary)
                        FilenameEditor(
                            itemID: item.id,
                            filename: item.proposedFilename
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category").font(.caption).foregroundStyle(.secondary)
                        Picker("Category", selection: Binding(
                            get: { model.selectedPlanItem?.classification.category ?? .unclear },
                            set: { model.updateSelectedCategory($0) }
                        )) {
                            ForEach(ItemCategory.allCases, id: \.self) { category in
                                Label(category.folderName, systemImage: category.iconName).tag(category)
                            }
                        }
                        .labelsHidden()
                    }

                    InspectorSection(title: "Why this proposal") {
                        Text(item.classification.reason)
                        ConfidenceBadge(confidence: item.classification.confidence, sensitive: item.classification.isSensitive)
                    }

                    InspectorSection(title: "Destination and privacy") {
                        LabeledContent("Destination", value: item.relativeDestination)
                        LabeledContent(
                            "Proposal source",
                            value: item.classification.reason.hasPrefix("AI:") ? "OpenAI · metadata only" : "Local deterministic logic"
                        )
                        if item.hadCollision {
                            Label("Collision resolved without overwriting", systemImage: "exclamationmark.shield.fill")
                                .foregroundStyle(.orange)
                        } else {
                            Label("Destination is collision-free", systemImage: "checkmark.shield.fill")
                                .foregroundStyle(.green)
                        }
                    }

                    InspectorSection(title: "Original") {
                        LabeledContent("Name", value: item.scannedItem.filename)
                        LabeledContent("Location", value: item.scannedItem.relativePath)
                        LabeledContent("Size", value: ByteCountFormatter.string(fromByteCount: item.scannedItem.size, countStyle: .file))
                    }

                    HStack {
                        Button("Quick Look") { model.quickLookSelected() }
                        Button("Create Rule") { model.createRuleFromSelectedItem() }
                        Menu("Exclude") {
                            Button("This Filename") { model.excludeSelectedFilename() }
                        }
                        Spacer()
                        Button("Reject", role: .destructive) { model.rejectSelected() }
                    }
                }
                .padding(22)
            }
            .navigationTitle("Inspector")
        } else {
            ContentUnavailableView("Select a proposal", systemImage: "sidebar.right")
        }
    }
}

private struct SessionInspector: View {
    @EnvironmentObject private var model: AppModel
    let session: CleanupSession

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: session.state.iconName)
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text(session.sessionDirectoryName).font(.title2.bold())
            Text("\(session.itemCount) items · \(session.state.rawValue)")
                .foregroundStyle(.secondary)
            Button("Reveal in Finder") { model.reveal(session) }
            if session.state == .staged || session.state == .failed {
                Button("Undo Complete Session") { model.undo(session) }
                    .buttonStyle(.borderedProminent)
            }
            if session.state == .staged {
                Button("Keep Session as Final") { model.retain(session) }
                    .buttonStyle(.bordered)
            }
            if !model.selectedSessionFileURLs.isEmpty {
                Divider()
                Text("Organized files").font(.headline)
                Text("Drag an individual file to Finder or another app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                List(model.selectedSessionFileURLs, id: \.self) { url in
                    Label(url.lastPathComponent, systemImage: "doc.fill")
                        .lineLimit(1)
                        .draggable(url)
                        .accessibilityLabel("Drag organized file \(url.lastPathComponent)")
                }
                .frame(minHeight: 120, maxHeight: 240)
            }
            Spacer()
        }
        .padding(24)
    }
}

private struct MultiSelectionInspector: View {
    @EnvironmentObject private var model: AppModel
    let items: [PlanItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "checklist.checked")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("\(items.count) proposals selected")
                .font(.title2.bold())
            Text("Low-confidence and sensitive files remain unapproved by batch actions.")
                .foregroundStyle(.secondary)
            Button("Approve Selected Safe Items") { model.approveSelectedItems() }
                .buttonStyle(.borderedProminent)
            Button("Reject Selected Items", role: .destructive) { model.rejectSelectedItems() }
                .buttonStyle(.bordered)
            Spacer()
        }
        .padding(24)
    }
}

private struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FilenameEditor: View {
    @EnvironmentObject private var model: AppModel
    let itemID: UUID
    let filename: String
    @State private var draft: String
    @FocusState private var isFocused: Bool

    init(itemID: UUID, filename: String) {
        self.itemID = itemID
        self.filename = filename
        _draft = State(initialValue: filename)
    }

    var body: some View {
        TextField("Filename", text: $draft)
            .textFieldStyle(.roundedBorder)
            .focused($isFocused)
            .accessibilityIdentifier("inspector.filename")
            .onSubmit(commit)
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
            .onChange(of: itemID) { _, _ in
                draft = filename
            }
            .onChange(of: filename) { _, newValue in
                if !isFocused { draft = newValue }
            }
    }

    private func commit() {
        guard model.selectedPlanItemID == itemID else { return }
        model.updateSelectedFilename(draft)
        draft = model.selectedPlanItem?.proposedFilename ?? filename
    }
}

private struct ConfidenceBadge: View {
    let confidence: ClassificationConfidence
    let sensitive: Bool

    var body: some View {
        Text(sensitive ? "Sensitive" : confidence.rawValue.capitalized)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((sensitive ? Color.orange : confidence.color).opacity(0.14), in: Capsule())
            .foregroundStyle(sensitive ? .orange : confidence.color)
    }
}

private struct StatusBar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            if model.isBusy { ProgressView().controlSize(.small) }
            Text(model.statusMessage)
            Spacer()
            if model.plan != nil {
                Text("\(model.approvedCount) approved · \(model.pendingCount) pending")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 27)
        .background(.bar)
    }
}

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Desktop Cleaner").font(.headline)
            Text(model.statusMessage).font(.caption).foregroundStyle(.secondary)
            LabeledContent("Pending", value: "\(model.pendingCount)")
                .font(.caption)
            Divider()
            Button("Open Current Plan") { model.showMainWindow() }
                .disabled(model.plan == nil)
            Button("Scan \(model.selectedSource?.displayName ?? "Selected Source")") { model.scanSelectedSource() }
                .disabled(model.selectedSourceID == nil || model.isBusy)
            if let session = model.sessions.first {
                Button("Reveal Latest Session") { model.reveal(session) }
            }
            SettingsLink { Text("Settings…") }
            Divider()
            Button("Quit Desktop Cleaner") { NSApplication.shared.terminate(nil) }
        }
        .padding(12)
        .frame(width: 250)
    }
}

private extension ItemCategory {
    var iconName: String {
        switch self {
        case .documents: "doc.text.fill"
        case .screenshots: "camera.viewfinder"
        case .images: "photo.fill"
        case .video: "film.fill"
        case .audio: "waveform"
        case .installers: "shippingbox.fill"
        case .archives: "archivebox.fill"
        case .codeAndProjects: "chevron.left.forwardslash.chevron.right"
        case .fonts: "textformat"
        case .sensitive: "lock.shield.fill"
        case .duplicates: "square.on.square"
        case .unclear: "questionmark.folder.fill"
        }
    }

    var color: Color {
        switch self {
        case .documents: .blue
        case .screenshots: .purple
        case .images: .pink
        case .video: .indigo
        case .audio: .cyan
        case .installers: .orange
        case .archives: .brown
        case .codeAndProjects: .mint
        case .fonts: .teal
        case .sensitive: .red
        case .duplicates: .yellow
        case .unclear: .gray
        }
    }
}

private extension ClassificationConfidence {
    var color: Color {
        switch self {
        case .high: .green
        case .medium: .orange
        case .low: .red
        }
    }
}

private extension TransactionState {
    var iconName: String {
        switch self {
        case .staged: "checkmark.seal.fill"
        case .rolledBack: "arrow.uturn.backward.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .retained: "archivebox.fill"
        default: "clock.fill"
        }
    }
}
