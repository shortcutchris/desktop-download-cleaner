import SwiftUI

enum HelpTopic: String, CaseIterable, Identifiable {
    case guidedTour
    case gettingStarted
    case reviewPlan
    case stageAndUndo
    case safetyAndPrivacy
    case aiAssistance
    case rulesAndExclusions
    case shortcuts
    case troubleshooting

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .guidedTour: "Interactive Guided Tour"
        case .gettingStarted: "Getting Started"
        case .reviewPlan: "Reviewing a Cleanup Plan"
        case .stageAndUndo: "Staging and Undo"
        case .safetyAndPrivacy: "Safety and Privacy"
        case .aiAssistance: "OpenAI Assistance"
        case .rulesAndExclusions: "Rules and Exclusions"
        case .shortcuts: "Keyboard Shortcuts"
        case .troubleshooting: "Troubleshooting"
        }
    }

    var summaryKey: String {
        switch self {
        case .guidedTour: "Practice the complete workflow without touching any files."
        case .gettingStarted: "Authorize a source, choose a review folder, and create your first read-only plan."
        case .reviewPlan: "Understand proposals, confidence, collisions, and safe batch approval."
        case .stageAndUndo: "Apply approved changes transactionally and restore a complete session."
        case .safetyAndPrivacy: "See what Desktop Cleaner can access, change, store, and transmit."
        case .aiAssistance: "Configure metadata-only OpenAI proposals with an exact request preview."
        case .rulesAndExclusions: "Turn repeated decisions into local rules and keep unwanted items out of plans."
        case .shortcuts: "Move through the review workflow efficiently from the keyboard."
        case .troubleshooting: "Resolve access, staging, update, and recovery problems safely."
        }
    }

    var iconName: String {
        switch self {
        case .guidedTour: "point.topleft.down.to.point.bottomright.curvepath"
        case .gettingStarted: "figure.walk.arrival"
        case .reviewPlan: "checklist"
        case .stageAndUndo: "arrow.uturn.backward.circle"
        case .safetyAndPrivacy: "lock.shield"
        case .aiAssistance: "sparkles"
        case .rulesAndExclusions: "line.3.horizontal.decrease.circle"
        case .shortcuts: "keyboard"
        case .troubleshooting: "wrench.and.screwdriver"
        }
    }

    var instructionKeys: [String] {
        switch self {
        case .guidedTour:
            []
        case .gettingStarted:
            [
                "Choose Desktop, Downloads, or another folder through the system folder picker.",
                "Choose a visible review folder where approved files can be staged.",
                "Select a source and run Scan. Scanning and planning never move or delete files.",
                "Review the generated proposals before approving anything."
            ]
        case .reviewPlan:
            [
                "Use search and sorting to focus the proposal list.",
                "Select one proposal to inspect its original name, destination, reason, and privacy source.",
                "Edit the proposed filename or category when needed; the real extension stays protected.",
                "Approve safe proposals individually or in a batch. Sensitive and low-confidence items stay unapproved."
            ]
        case .stageAndUndo:
            [
                "Stage Approved Files performs a fresh safety check before any move or copy.",
                "Every completed step is appended to a durable transaction journal.",
                "Open a staged session from the sidebar to reveal it, drag out files, or undo the complete session.",
                "Keep as Final closes the undo window without moving or deleting staged files."
            ]
        case .safetyAndPrivacy:
            [
                "Desktop Cleaner accesses only folders you explicitly choose through macOS.",
                "No scan, plan, rule, or help action deletes files automatically.",
                "API keys are stored only in macOS Keychain and never in settings, logs, or diagnostics.",
                "The diagnostics preview excludes file names, paths, contents, credentials, and model payloads."
            ]
        case .aiAssistance:
            [
                "Add your own OpenAI API key in Settings and keep AI Off until you choose to enable it.",
                "Metadata only sends the filename, extension, type, size range, and dates for eligible items.",
                "Review the exact item list and data fields before sending each request.",
                "AI output is validated locally and can never approve, delete, execute commands, or choose absolute paths."
            ]
        case .rulesAndExclusions:
            [
                "Create a rule from a reviewed proposal or add one in Settings.",
                "Rules run locally in order; the first enabled matching rule wins.",
                "Use filename, extension, or relative-path exclusions with * and ? wildcards.",
                "Sensitive-file protections take priority over user rules."
            ]
        case .shortcuts:
            [
                "Command-R — scan the selected source.",
                "Command-Shift-A — approve safe proposals.",
                "Command-Option-A — select all visible proposals.",
                "Command-Shift-Return — approve selected safe proposals.",
                "Command-Return — stage approved files.",
                "Space — Quick Look the selected proposal."
            ]
        case .troubleshooting:
            [
                "If folder access expired, choose the folder again in Settings.",
                "If a source changed after scanning, scan again before staging.",
                "If undo reports an occupied original path, move the occupant and retry; nothing is overwritten.",
                "Use Recovery Required when a previous transaction was interrupted.",
                "Preview a redacted diagnostics export before sharing technical details."
            ]
        }
    }

    var reminderKey: String {
        switch self {
        case .guidedTour: "This tour is a simulation. It never reads, creates, moves, or deletes files."
        case .gettingStarted: "A plan is only a proposal. Nothing changes until you approve and stage items."
        case .reviewPlan: "Low confidence and sensitive items always require deliberate individual review."
        case .stageAndUndo: "Existing destination files are never overwritten."
        case .safetyAndPrivacy: "File content is never sent to an AI provider by the current metadata-only capability."
        case .aiAssistance: "AI is optional; the complete deterministic workflow works without it."
        case .rulesAndExclusions: "Rules affect new plans only and never mutate files in the background."
        case .shortcuts: "Consequential shortcuts remain disabled until their safety conditions are satisfied."
        case .troubleshooting: "When uncertain, stop and scan again. Desktop Cleaner preserves the local plan whenever possible."
        }
    }
}

struct HelpView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: HelpTopic = .guidedTour
    @State private var searchText = ""

    private var visibleTopics: [HelpTopic] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return HelpTopic.allCases
        }
        return HelpTopic.allCases.filter { topic in
            ([topic.titleKey, topic.summaryKey, topic.reminderKey] + topic.instructionKeys)
                .map { model.localized($0) }
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationSplitView {
            List(visibleTopics, selection: $selection) { topic in
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.localized(topic.titleKey))
                            .fontWeight(.medium)
                        Text(model.localized(topic.summaryKey))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                } icon: {
                    Image(systemName: topic.iconName)
                }
                .tag(topic)
                .accessibilityIdentifier("help.topic.\(topic.rawValue)")
            }
            .navigationTitle(model.localized("Help & Guide"))
            .searchable(text: $searchText, prompt: Text(model.localized("Search help")))
            .accessibilityIdentifier("help.search")
            .overlay {
                if visibleTopics.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        } detail: {
            if selection == .guidedTour {
                GuidedHelpTour()
                    .environmentObject(model)
            } else {
                HelpArticle(topic: selection)
                    .environmentObject(model)
            }
        }
        .navigationTitle(model.localized("Desktop Cleaner Help"))
        .frame(minWidth: 860, minHeight: 600)
    }
}

private struct HelpArticle: View {
    @EnvironmentObject private var model: AppModel
    let topic: HelpTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Label(model.localized(topic.titleKey), systemImage: topic.iconName)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.tint)
                Text(model.localized(topic.summaryKey))
                    .font(.title3)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 14) {
                    Text("What to do")
                        .font(.headline)
                    ForEach(Array(topic.instructionKeys.enumerated()), id: \.offset) { index, key in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.accentColor, in: Circle())
                            Text(model.localized(key))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                GroupBox {
                    Label(model.localized(topic.reminderKey), systemImage: "checkmark.shield.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                } label: {
                    Text("Remember")
                }
            }
            .padding(30)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }
}

private struct GuidedHelpTour: View {
    @EnvironmentObject private var model: AppModel
    @State private var step = 0
    @State private var sourceSelected = false
    @State private var planCreated = false
    @State private var proposalApproved = false
    @State private var sessionStaged = false
    @State private var sessionUndone = false

    private let stepTitleKeys = [
        "Choose a Source",
        "Create a Read-Only Plan",
        "Review and Approve",
        "Stage Safely",
        "Undo the Session"
    ]

    private let stepBodyKeys = [
        "In the real app, macOS grants access only after you choose a folder. This simulation requests no access.",
        "Scanning collects metadata and creates proposals. It does not rename, move, copy, or delete files.",
        "Inspect the destination, reason, confidence, and privacy source before approving a proposal.",
        "Staging revalidates every source and records each successful operation in the transaction journal.",
        "Undo restores the complete staged session where possible and never overwrites an occupied path."
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Label("Interactive Guided Tour", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.tint)
                    Spacer()
                    Button("Reset Tour") { reset() }
                        .accessibilityIdentifier("help.tour.reset")
                }

                Text("Practice the complete workflow without touching any files.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                ProgressView(value: Double(step + 1), total: Double(stepTitleKeys.count))
                    .accessibilityLabel(model.localized("Tour progress"))
                    .accessibilityValue(model.localized("Step %@ of %@", String(step + 1), String(stepTitleKeys.count)))

                HStack(spacing: 8) {
                    ForEach(stepTitleKeys.indices, id: \.self) { index in
                        Circle()
                            .fill(index <= step ? Color.accentColor : Color.secondary.opacity(0.2))
                            .frame(width: 10, height: 10)
                    }
                }
                .accessibilityHidden(true)

                GroupBox {
                    VStack(alignment: .leading, spacing: 18) {
                        Label(
                            model.localized("Step %@ of %@", String(step + 1), String(stepTitleKeys.count)),
                            systemImage: stepIcon
                        )
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        Text(model.localized(stepTitleKeys[step]))
                            .font(.title.bold())
                            .accessibilityIdentifier("help.tour.stepTitle")
                            .accessibilityLabel(model.localized(stepTitleKeys[step]))
                        Text(model.localized(stepBodyKeys[step]))
                            .foregroundStyle(.secondary)
                        practiceCard
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                } label: {
                    Text("Safe Practice")
                }

                Label(
                    "This tour is a simulation. It never reads, creates, moves, or deletes files.",
                    systemImage: "lock.shield.fill"
                )
                .font(.callout)
                .foregroundStyle(.secondary)

                HStack {
                    Button("Back") { step = max(0, step - 1) }
                        .disabled(step == 0)
                        .accessibilityIdentifier("help.tour.back")
                    Spacer()
                    Button(model.localized(step == stepTitleKeys.count - 1 ? "Start Over" : "Next")) {
                        if step == stepTitleKeys.count - 1 {
                            reset()
                        } else {
                            step += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("help.tour.next")
                }
            }
            .padding(30)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }

    @ViewBuilder
    private var practiceCard: some View {
        switch step {
        case 0:
            HelpPracticeRow(
                title: model.localized("Sample Downloads Folder"),
                detail: model.localized("No folder access is requested."),
                isComplete: sourceSelected,
                actionTitle: model.localized(sourceSelected ? "Selected" : "Select Sample")
            ) { sourceSelected = true }
        case 1:
            HelpPracticeRow(
                title: model.localized("Project Proposal (2).pdf"),
                detail: model.localized(planCreated ? "Proposal: Project Proposal.pdf → Documents" : "Ready for a simulated scan"),
                isComplete: planCreated,
                actionTitle: model.localized(planCreated ? "Plan Ready" : "Create Sample Plan")
            ) {
                sourceSelected = true
                planCreated = true
            }
        case 2:
            HelpPracticeRow(
                title: model.localized("Project Proposal.pdf"),
                detail: model.localized("Documents · High confidence · Local logic"),
                isComplete: proposalApproved,
                actionTitle: model.localized(proposalApproved ? "Approved" : "Approve Sample")
            ) {
                sourceSelected = true
                planCreated = true
                proposalApproved.toggle()
            }
        case 3:
            HelpPracticeRow(
                title: model.localized("Visible Review Folder / Documents"),
                detail: model.localized(sessionStaged ? "Sample session staged with a transaction journal" : "Existing files would never be overwritten"),
                isComplete: sessionStaged,
                actionTitle: model.localized(sessionStaged ? "Staged" : "Stage Sample")
            ) {
                sourceSelected = true
                planCreated = true
                proposalApproved = true
                sessionStaged = true
                sessionUndone = false
            }
        default:
            HelpPracticeRow(
                title: model.localized("Sample Cleanup Session"),
                detail: model.localized(sessionUndone ? "Sample restored to its original location" : "The whole staged session can be restored"),
                isComplete: sessionUndone,
                actionTitle: model.localized(sessionUndone ? "Restored" : "Undo Sample")
            ) {
                sourceSelected = true
                planCreated = true
                proposalApproved = true
                sessionStaged = false
                sessionUndone = true
            }
        }
    }

    private var stepIcon: String {
        ["folder.badge.plus", "sparkle.magnifyingglass", "checkmark.circle", "shippingbox", "arrow.uturn.backward.circle"][step]
    }

    private func reset() {
        step = 0
        sourceSelected = false
        planCreated = false
        proposalApproved = false
        sessionStaged = false
        sessionUndone = false
    }
}

private struct HelpPracticeRow: View {
    let title: String
    let detail: String
    let isComplete: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle.dashed")
                .font(.title2)
                .foregroundStyle(isComplete ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).fontWeight(.medium)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(actionTitle, action: action)
                .disabled(isComplete)
                .accessibilityIdentifier("help.tour.action")
        }
        .padding(14)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
    }
}
