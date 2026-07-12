# Implementation plan

## Phase 0 — Repository and delivery foundation

- Create the Xcode project with macOS application and test targets.
- Set the scheme to `DesktopCleaner` and commit the shared scheme.
- Configure SwiftLint/formatting only if it runs reliably in CI.
- Add GitHub Actions for build and tests.
- Add Sparkle 2 behind a disabled development feed.
- Establish semantic versioning, build numbers, changelog, and release-note conventions.
- Add a minimal app icon placeholder only until a deliberate icon design is approved.

Exit criterion: clean clone builds and tests locally and in CI.

## Phase 1 — Safe local core

- Implement domain models and source-folder permissions.
- Implement read-only scanning against temporary fixture folders.
- Implement deterministic classification and exclusions.
- Implement local rename normalization and collision-safe destination planning.
- Build unit and integration tests before connecting real user folders.

Exit criterion: a tested CLI-like service layer can scan fixtures and produce a plan without mutation.

## Phase 2 — Native review experience

- Build onboarding and folder access.
- Build the source sidebar, plan list, inspector, Quick Look, search, grouping, and approval states.
- Add editable proposed names and destinations with immediate validation.
- Add accessibility identifiers and keyboard workflows.

Exit criterion: the user can review and edit a realistic plan in a runnable application.

## Phase 3 — Transactional staging and undo

- Implement transaction preflight, journal, executor, recovery, and rollback.
- Add staged-session history and reveal-in-Finder actions.
- Test partial failure, collisions, disappeared sources, occupied rollback paths, app termination, and relaunch recovery.

Exit criterion: approved fixture files can be staged and completely undone after relaunch.

## Phase 4 — Rules

- Add ordered user rules and conversion from an accepted decision to a proposed rule.
- Add rule conflict detection, enable/disable, edit, import, and export.

Exit criterion: common cleanup behavior works repeatedly without AI.

## Phase 5 — OpenAI assistance

- Add Keychain-backed API key settings and connection test.
- Implement provider-neutral AI interface and OpenAI Responses adapter.
- Add strict Structured Outputs validation.
- Add metadata-only batch proposals first.
- Add explicit text/visual preview permissions only after metadata flow is tested.
- Add request preview, cancellation, failure handling, and usage indication.

Exit criterion: AI enriches plans but cannot bypass local safety rules or block manual cleanup.

## Phase 6 — Product polish and release

- Add menu bar entry point, notifications, launch-at-login, onboarding polish, and update UI.
- Commission or generate a deliberate full-bleed macOS app icon and verify the complete icon asset pipeline.
- Complete VoiceOver, keyboard, reduced-motion, light/dark, and high-contrast QA.
- Add signing, notarization, GitHub Release, appcast signing, installation, and launch verification automation.
- Prepare README screenshots, privacy documentation, and version-specific release notes.

Exit criterion: signed and notarized 1.0 release with verified Sparkle update path.

## Recommended issue order

Create small issues from the phases instead of implementing the entire app in one unreviewable change. The first implementation session should complete Phase 0 and begin Phase 1, not jump directly into AI or visual polish.

