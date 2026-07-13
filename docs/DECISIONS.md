# Product and architecture decisions

## Accepted at repository bootstrap

### Separate product from Yoink

The app is an organizer and review workflow, not a temporary drag-and-drop shelf.

### Visible review folder

Approved files are staged in a user-visible, configurable review root rather than a hidden system temporary directory.

### Plan before mutation

Scan and plan are read-only. Filesystem mutation begins only after explicit approval and transaction preflight.

### No automatic deletion

Version 1 never deletes files automatically. Trash or deletion functionality is out of scope until separately designed.

### Local-first behavior

The complete deterministic workflow remains useful without an OpenAI key. AI augments explanations, classification, and filenames.

### Declarative AI output

AI returns schema-validated proposals. It cannot supply executable code, absolute filesystem paths, extensions, or destructive actions.

### Public repository after release approval

The repository started private while product naming, code signing, privacy language, and release readiness were developed. The owner explicitly approved public visibility after the signed and notarized 1.1 release was verified.

## Accepted for 1.0

### Metadata-only AI boundary

The first release enables only the tested metadata capability. Text and visual preview transmission stay unavailable until separate per-capability extraction limits, per-file eligibility, exact preview UI, and tests exist. This preserves the product contract that file content is never transmitted implicitly.

### Deliberate icon identity

The 1.0 icon uses an original dark-navy 3D document organizer with a metallic containment ring and shield check. It communicates organization, review, and safety rather than deletion, trash, or generic cleanup.

### Signed public update boundary

The public GitHub release assets serve as the stable Sparkle feed after explicit authorization. Manual checks are available and automatic checks are opt-in. Every update must still be Developer ID signed, Apple notarized, and protected by the app's dedicated Sparkle EdDSA signature.

Because Desktop Cleaner is sandboxed, Sparkle's Installer Launcher XPC service is enabled with only the documented `-spks` and `-spki` Mach lookup exceptions. The Downloader XPC service remains disabled because the app already has outgoing network access for its opt-in OpenAI and update capabilities.

### Explicit session finalization

A staged session remains rollback-capable until the user chooses “Keep as Final.” Finalization changes only the durable journal state and never moves or deletes the staged files. A retained journal cannot later be rolled back accidentally.

### Persisted scan policy remains local

Per-source enablement and depth, the minimum-age threshold, and glob exclusions are evaluated locally before planning. Missing timestamps remain visible instead of being silently filtered, and exclusions remove matching items from the plan without mutating their source files.

### Hash duplicates only when metadata makes a match possible

Duplicate detection hashes only eligible files that share a non-zero size. Sensitive, excluded, alias, symlink, and package items are not read. The digest is ephemeral, stays local, and marks only later deterministic matches as duplicates; the first stable relative path remains the reference item.

### Persist plans, consume them after staging

The current plan and its user decisions survive relaunch so review work is not lost. Transaction preflight still revalidates source identity before mutation. Once staging succeeds, the persisted plan is cleared because its source state has been consumed and replaying it would be misleading.

### Diagnostics use an aggregate-only data shape

The diagnostics exporter accepts counts, booleans, enum settings, app version, and operating-system version only. It never accepts source folders, plan items, transaction steps, errors, file names, paths, credentials, or model payloads, making redaction a structural boundary rather than a best-effort text filter.

## Accepted for 1.2

### Runtime language selection does not rewrite cleanup data

Desktop Cleaner ships English and German resource bundles and defaults to the macOS language. The user can switch the interface immediately in Settings, and the explicit choice persists locally. SwiftUI labels and dynamic app messages use the selected locale, and OpenAI proposal reasons request the same language. Stable category directory names, existing plans, filenames, paths, rules, and journals are never translated or rewritten, preserving transaction and rollback identities. Adding another language is limited to the central language manifest and one localized resource bundle.

## Accepted for 1.3

### Interactive Help is structurally isolated from user data

The searchable Help center is fully offline and localized through the existing resource bundles. Its guided workflow uses fixed sample labels and ephemeral SwiftUI view state only. It has no access to folder bookmarks, scanners, plans, transactions, persistence, Keychain, or network adapters, so practicing source selection, planning, approval, staging, and undo cannot touch or transmit user data.

### The in-app changelog is a bundled release manifest

The app displays release history from a bundled JSON manifest rather than fetching mutable remote content or trying to parse Markdown at runtime. The manifest is versioned with the release, localized through the same bundles as the interface, and validated against the build settings. The main-window build summary and Settings history share that source, preventing their release descriptions from drifting apart.

## Remaining distribution decisions

- Whether move or copy should remain the default after usability testing
- Paid distribution, direct download, or Mac App Store strategy
