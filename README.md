# Desktop Cleaner

Desktop Cleaner is a native macOS utility for safely organizing files accumulated in Desktop, Downloads, and explicitly selected folders. It creates a reviewable plan before anything moves, stages only approved files in a visible review folder, and can undo a complete session.

> Nothing moves until the user approves it, nothing is deleted automatically, and every staged cleanup session can be undone.

## What 1.0 includes

- Sandboxed, security-scoped access to user-selected source and review folders.
- Read-only scanning with per-source depth and enablement, an optional minimum-age threshold, editable glob exclusions, deterministic categories, sensitive-file protection, and safe filename cleanup.
- Searchable grouped proposals, Quick Look, editable filenames and categories, partial approval, and explicit local rules.
- Collision-safe move or copy transactions with append-only JSON journals, restart recovery, complete rollback, and an explicit “keep as final” state.
- Optional cancellable metadata-only OpenAI proposals through the Responses API and strict Structured Outputs, with an exact item preview and approximate input-use indication.
- A user-owned API key stored only in macOS Keychain, request-scope preview, connection test, and key deletion.
- Menu bar access, launch at login, staging notifications, app-data reset, Sparkle integration, and a complete macOS icon set.

Desktop Cleaner is not a drag-and-drop shelf and not a general system cleaner. It never automatically deletes files.

## Privacy

The complete local workflow works without OpenAI. AI is off by default. In 1.0, the only enabled AI capability is metadata-only organization; file contents, absolute paths, previews, commands, and approval decisions are not sent. Sensitive filenames and extensions are always excluded from AI batches. See [docs/PRIVACY.md](docs/PRIVACY.md).

Do not store API keys in JSON, `.env`, plist, UserDefaults, source code, logs, or the repository. The app stores the user-owned key in Keychain under service `com.desktopcleaner.openai`.

## Build and test

Requirements: macOS 14 or newer, Xcode 16.4 or newer, and XcodeGen when changing target definitions.

```sh
xcodegen generate
xcodebuild build -project DesktopCleaner.xcodeproj -scheme DesktopCleaner -destination 'platform=macOS' CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=-
xcodebuild test -project DesktopCleaner.xcodeproj -scheme DesktopCleaner -destination 'platform=macOS' CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=-
```

The shared `DesktopCleaner` scheme runs unit, temporary-directory integration, and UI tests. Integration and UI fixtures use temporary directories and never alter the real Desktop or Downloads folders.

## Repository guide

- [SESSION_BRIEF.md](SESSION_BRIEF.md) — mission and safety summary
- [SPEC.md](SPEC.md) — product contract
- [ARCHITECTURE.md](ARCHITECTURE.md) — technical boundaries
- [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) — phased delivery plan
- [docs/DECISIONS.md](docs/DECISIONS.md) — deliberate product and architecture decisions
- [docs/RELEASING.md](docs/RELEASING.md) — signed release procedure

`project.yml` is the checked-in XcodeGen source of truth. Regenerate `DesktopCleaner.xcodeproj` after target or build-setting changes.
