# Desktop & Download Cleaner

Native macOS utility for reviewing, organizing, and safely renaming accumulated files from Desktop, Downloads, and user-selected folders.

The app is deliberately **not a Yoink clone**. Yoink solves temporary drag-and-drop storage. This project solves the later cleanup problem: understanding what has accumulated, preparing a safe organization plan, reviewing it, and applying it with a complete undo trail.

## Project status

Product specification and implementation briefing are complete. Application code has not been started yet.

## Start here

1. Read [SESSION_BRIEF.md](SESSION_BRIEF.md).
2. Treat [SPEC.md](SPEC.md) as the product contract.
3. Follow [ARCHITECTURE.md](ARCHITECTURE.md) and [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md).
4. Follow all repository rules in [AGENTS.md](AGENTS.md).

## Product promise

> Nothing moves until the user approves it, nothing is deleted automatically, and every applied cleanup session can be undone.

## Planned technology

- Swift 6 and SwiftUI
- Native macOS application, macOS 14 or newer
- Security-scoped folder access
- Local-first deterministic classification
- Optional OpenAI assistance through the Responses API
- macOS Keychain for the user's API key
- Sparkle 2 for updates outside the Mac App Store
- GitHub Actions, signed and notarized GitHub releases

The working product and scheme name is `DesktopCleaner`. Branding can be changed later without changing the product scope.

