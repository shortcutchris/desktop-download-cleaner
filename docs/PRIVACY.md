# Privacy

Desktop Cleaner is local-first. Scanning, deterministic classification, filename cleanup, rules, approval, staging, journaling, recovery, and rollback work without an online service.

## Local data

The app stores security-scoped bookmarks, settings, rules, session summaries, and human-readable transaction journals under its sandbox and application-support locations. It does not store file contents in its database. “Delete All App Data” removes Desktop Cleaner metadata, settings, bookmarks, journals, sessions, rules, and the Keychain API key without deleting user files.

## OpenAI

AI is off by default and requires a visible user action. Version 1.0 enables metadata-only proposals. Before sending, the app shows the batch size and transmitted fields:

- filename and extension
- Uniform Type Identifier
- approximate size range
- creation and modification dates

Sensitive files are excluded. File contents, absolute paths, text or visual previews, commands, and approval decisions are not sent. Requests use `store: false`, and all returned proposals are validated against a strict local allowlist and filename/path safety rules.

The user supplies their own OpenAI API key. It is stored only in macOS Keychain and is never written to JSON, plist, UserDefaults, logs, source code, or repository files.

Text and visual preview transmission remain disabled until each capability has separate extraction limits, per-file eligibility, exact preview UI, and dedicated tests. This is a deliberate safety boundary, not a hidden fallback.

## Local duplicate detection

Duplicate detection groups eligible files by metadata size and hashes only groups that could actually match. Hashing happens locally beneath the authorized source, skips sensitive, excluded, alias, symlink, and package items, and neither stores nor transmits hashes or contents.

## Diagnostics export

The diagnostics report is built from aggregate counts and non-sensitive settings rather than from source, plan, or journal objects. The app shows the exact JSON before saving it. Filenames, paths, file contents, API-key values, model requests/responses, and failure strings are structurally absent.
