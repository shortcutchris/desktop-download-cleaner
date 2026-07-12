# Desktop Cleaner delivery rules

These repository-local rules apply to every future coding task.

## Product contract

- Read `SESSION_BRIEF.md`, `SPEC.md`, `ARCHITECTURE.md`, and `IMPLEMENTATION_PLAN.md` before implementing.
- Treat the safety invariants in `SPEC.md` as non-negotiable.
- Do not broaden the app into a drag-and-drop shelf or a general system cleaner.
- Do not send file content to an AI provider without an explicit per-capability user setting.

## Validation

- Build every source or configuration change with the `DesktopCleaner` scheme for macOS.
- Run the complete `DesktopCleaner` test suite before declaring a change complete.
- For user-interface changes, verify the affected interaction in a runnable build whenever local UI control is available.
- Add unit tests for planning, filename sanitization, collision handling, transaction logging, rollback, exclusions, and AI response validation.
- Add integration tests using temporary directories; tests must never alter the user's real Desktop or Downloads folders.
- Report the exact validation result, including the number of passing tests.

## Documentation

- Keep `CHANGELOG.md` current for every release.
- Add version-specific notes under `release-notes/<version>.md` for every release.
- Update `README.md`, `SPEC.md`, or examples whenever behavior, setup, privacy, or user-facing capabilities change materially.
- Record deliberate scope or architecture changes in `docs/DECISIONS.md`.

## Delivery

- Use semantic versioning and increment `CURRENT_PROJECT_VERSION` for releases.
- A complete delivery includes: version bump, release notes, build, all tests, focused commit, pull request, successful CI, merge, version tag, signed and notarized GitHub release, Sparkle appcast update, local installation, and launch verification.
- Verify release assets and the appcast after publishing.
- Do not publish an external release for exploratory work, reviews, or local-only requests unless explicitly requested.
- Never commit API keys, signing credentials, notarization credentials, Sparkle private keys, or generated secret files.

## Git hygiene

- Preserve unrelated user changes.
- Keep commits focused and understandable.
- Never force-push the default branch.
- Prefer pull requests for implementation work after the initial repository bootstrap.

