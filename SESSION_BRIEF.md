# Build briefing for a new Codex session

## Mission

Build a polished native macOS app that safely organizes files accumulated in Desktop, Downloads, and explicitly selected folders. The app creates a reviewable cleanup plan, optionally uses OpenAI for classification and rename suggestions, stages approved changes in a visible review folder, and can undo an entire applied session.

## Required first action

Before writing code, read the following files completely:

- `AGENTS.md`
- `SPEC.md`
- `ARCHITECTURE.md`
- `IMPLEMENTATION_PLAN.md`
- `docs/RESEARCH.md`
- `docs/DECISIONS.md`

Then inspect the repository state and start with Phase 0 and Phase 1 from `IMPLEMENTATION_PLAN.md`. Do not ask the user to repeat the product concept unless a genuinely material decision is missing.

## Core priorities

1. Safety and undoability before automation.
2. A useful deterministic local cleaner before AI features.
3. Clear preview and approval before any filesystem mutation.
4. Privacy controls that make transmitted data obvious.
5. Native Mac interaction and visual polish.
6. Tests around every filesystem boundary.

## Hard boundaries

- Do not implement a Yoink-style shelf.
- Do not delete files automatically.
- Do not move files during scanning or planning.
- Do not let model output become an unchecked filesystem path or shell command.
- Do not store an OpenAI key in source code, plist files, UserDefaults, logs, crash reports, or the repository.
- Do not access folders the user has not explicitly granted.

## Definition of the first usable milestone

A user can grant Desktop and Downloads access, scan them, review deterministic categories and safe rename suggestions, approve a subset, stage the approved files into a session folder, inspect the transaction log, and undo the complete session. AI can remain behind a disabled feature boundary until the local workflow is reliable.

