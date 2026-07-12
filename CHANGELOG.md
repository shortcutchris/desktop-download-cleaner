# Changelog

All notable changes are documented here. The project follows semantic versioning and the Keep a Changelog format.

## [Unreleased]

## [1.2.0] - 2026-07-12

### Added

- Complete German and English localization across onboarding, workspace, inspector, settings, menu bar, commands, status messages, errors, notifications, and deterministic explanations.
- A persistent runtime language picker with system-default, English, and German choices.
- A bundle-based localization manifest and format-placeholder validation that make future languages a small resource-only extension.

### Changed

- OpenAI metadata proposal reasons now follow the selected interface language without changing the metadata-only privacy boundary.
- Stable category folders, saved rules, filenames, plans, and transaction paths remain unchanged when the interface language switches.

## [1.1.4] - 2026-07-12

### Changed

- Published a clean signed update target for end-to-end validation from the updater-capable 1.1.3 release.

## [1.1.3] - 2026-07-12

### Fixed

- Sandboxed installations now launch Sparkle's required Installer XPC service with the documented Mach-service exceptions.
- Release automation now rejects archives that omit the required Sparkle sandbox configuration.

## [1.1.2] - 2026-07-12

### Fixed

- Release checksum files now contain portable asset filenames instead of local build paths.

## [1.1.1] - 2026-07-12

### Added

- Manual “Check for Updates…” actions in Settings and the application menu.
- An opt-in automatic update preference backed by Sparkle's signed public release feed.

### Changed

- Public distribution and update documentation now reflect the approved public GitHub repository.

## [1.1.0] - 2026-07-12

### Added

- Desktop and Downloads picker shortcuts plus persisted per-source enablement and scan-depth controls.
- Persisted filename, extension, and relative-path glob exclusions and an optional minimum file-age scan policy.
- Explicit session finalization, restart-safe security-scope reacquisition for rollback, menu-bar pending counts, and core keyboard shortcuts.
- Exact AI batch item preview, approximate input-token indication, and user cancellation without discarding the local plan.
- Local hash-on-demand duplicate detection that never uploads or persists file content.
- Sortable multi-selection review, exact destination/collision/privacy details, and drag-out of individual staged files.
- Persistent current-plan decisions, configurable renaming/date/collision styles, AI quality, and finalized-session history retention.
- Exact-preview redacted diagnostics export that structurally excludes filenames, paths, file contents, credentials, and model payloads.

### Changed

- App-data reset now also clears the minimum-age scan policy while continuing to leave all user files untouched.
- A successful staging transaction clears the now-consumed current plan so it cannot be applied twice.
- Release automation now re-signs Sparkle's embedded helpers with Developer ID and secure timestamps before notarization.
- Desktop Cleaner now embeds its dedicated Sparkle public update key, while the private key remains in macOS Keychain.

## [1.0.0] - 2026-07-12

### Added

- Native SwiftUI onboarding, three-column review workspace, inspector editing, search, Quick Look, settings, and menu bar entry point.
- Security-scoped folder authorization, read-only bounded scanning, deterministic classification, exclusions, sensitive-file defaults, and explicit ordered rules.
- Safe filename normalization, extension preservation, collision handling, and relative destination validation.
- Transactional move/copy staging with preflight, append-only journals, partial-failure recovery, restart recovery, and complete rollback.
- Keychain-only OpenAI API key management, connection testing, metadata request preview, Responses API Structured Outputs, retry/backoff, and local response validation.
- Launch-at-login, staging notifications, app-data reset that never deletes user files, disabled-by-default Sparkle integration, CI, and a complete premium macOS icon set.
- Unit, temporary-directory integration, and macOS UI test coverage for the critical safety and interaction boundaries.

### Security

- Sensitive files are excluded from AI batches.
- API keys, file contents, absolute paths, and generated secret files are excluded from repository storage and diagnostic payloads.
- AI output cannot supply extensions, absolute paths, commands, deletion actions, or approval decisions.
