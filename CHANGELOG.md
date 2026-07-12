# Changelog

All notable changes are documented here. The project follows semantic versioning and the Keep a Changelog format.

## [Unreleased]

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
