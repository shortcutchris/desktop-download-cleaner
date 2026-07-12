# Architecture

## Technical direction

Build a native SwiftUI macOS application with narrow, testable services and explicit filesystem boundaries. UI code must not call `FileManager` or the OpenAI API directly.

## Proposed targets

- `DesktopCleaner`: application target and composition root
- `DesktopCleanerCore`: domain models and pure planning logic
- `DesktopCleanerServices`: folder access, scan, transaction, Keychain, and AI adapters
- `DesktopCleanerTests`: unit tests
- `DesktopCleanerIntegrationTests`: temporary-directory filesystem tests
- `DesktopCleanerUITests`: critical workflow tests

These may begin as Xcode targets and later become local Swift packages if build times or reuse justify it.

## Main modules

### FolderAccessService

Owns folder picker results and security-scoped bookmarks. No other component persists raw access tokens.

### Scanner

Produces immutable `ScannedItem` values. Scanning is read-only and cancellable. Hashing and content extraction are separate opt-in jobs.

### ClassificationEngine

Applies ordered deterministic classifiers and exclusions. It produces category, confidence, and explanation without filesystem mutation.

### PlanningEngine

Combines scan results, rules, optional AI proposals, and user edits into a `CleanupPlan`. All target paths are relative to the configured review root and are locally sanitized.

### AIProposalService

Defines a provider-neutral protocol. The OpenAI adapter uses Responses API and strict Structured Outputs. Model responses never cross into filesystem operations without validation by the planning engine.

### TransactionExecutor

Executes a preflighted `CleanupTransaction`, writes an append-only journal, and exposes recovery and rollback. It must be actor-isolated so that two sessions cannot mutate the same files concurrently.

### SessionStore

Persists scan summaries, plans, user decisions, and transaction journals. SwiftData is acceptable for metadata, but the transaction journal should also have a durable, human-readable representation inside app support.

### KeychainStore

Stores and removes the user-owned OpenAI key. Exposes no logging representation.

### UpdateService

Wraps Sparkle so update behavior remains separate from application state.

### Localization

The application target owns a small `AppLanguage` manifest and localized resource bundles. SwiftUI receives the selected locale at each scene root, while dynamic status, error, notification, and domain-display strings pass through the same bundle-backed formatter. Persisted enums, category folder names, user-authored rules, filenames, and transaction paths remain language-neutral or unchanged, so switching the interface language never mutates cleanup data. A new language requires one manifest entry and one `<code>.lproj/Localizable.strings` resource.

## Core models

```text
SourceFolder
ScannedItem
Classification
RenameProposal
DestinationProposal
CleanupPlan
PlanItem
UserRule
CleanupSession
TransactionStep
TransactionJournal
AIPrivacyLevel
```

Use stable UUIDs and persist source identity information sufficient to detect that a file changed between scan and execution.

## Transaction state machine

```text
draft -> preflighting -> applying -> staged
                    \-> failed -> rollingBack -> rolledBack
staged -> rollingBack -> rolledBack
staged -> retained
```

The journal is the recovery authority. On launch, any session left in `applying` or `rollingBack` is inspected and the user receives a safe recovery action.

## Path safety

- Model output can provide only proposed basenames and category identifiers from an allowlist.
- Construct final URLs locally beneath the review root.
- Resolve standardized URLs and verify containment beneath the review root.
- Reject path separators, traversal components, null/control characters, absolute paths, and reserved names.
- Use coordinated file access where needed.
- Never follow symlinks into ungranted locations during recursive scans.

## AI response schema concept

```json
{
  "items": [
    {
      "id": "stable-input-id",
      "category": "documents",
      "suggested_basename": "Project proposal – July 2026",
      "confidence": "high",
      "reason": "The filename and preview identify a dated project proposal.",
      "warnings": []
    }
  ]
}
```

The schema does not permit absolute paths, extensions, deletion flags, or commands.

## Observability

Use structured local logging with privacy annotations. File paths, filenames, extracted text, API keys, and model payloads are private and redacted by default. Provide debug export with an explicit preview of included data.

## Shared future package

The Keychain, networking, OpenAI Responses client, error mapping, and update conventions may later be extracted into a separate local Swift package shared with Skill Notes. Do not couple the repositories before both applications have stable requirements.
