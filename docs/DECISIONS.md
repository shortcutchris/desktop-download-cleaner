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

### Private repository initially

The repository starts private while product naming, code signing, privacy language, and release readiness are developed. Public visibility is a deliberate release decision.

## Accepted for 1.0

### Metadata-only AI boundary

The first release enables only the tested metadata capability. Text and visual preview transmission stay unavailable until separate per-capability extraction limits, per-file eligibility, exact preview UI, and tests exist. This preserves the product contract that file content is never transmitted implicitly.

### Deliberate icon identity

The 1.0 icon uses an original dark-navy 3D document organizer with a metallic containment ring and shield check. It communicates organization, review, and safety rather than deletion, trash, or generic cleanup.

### Private release boundary

The repository remains private. Sparkle automatic checks remain disabled because private GitHub assets cannot serve as a general public update feed. External release publication and repository visibility require explicit authorization after signing, notarization, and appcast verification.

### Explicit session finalization

A staged session remains rollback-capable until the user chooses “Keep as Final.” Finalization changes only the durable journal state and never moves or deletes the staged files. A retained journal cannot later be rolled back accidentally.

### Persisted scan policy remains local

Per-source enablement and depth, the minimum-age threshold, and glob exclusions are evaluated locally before planning. Missing timestamps remain visible instead of being silently filtered, and exclusions remove matching items from the plan without mutating their source files.

## Remaining distribution decisions

- Whether move or copy should remain the default after usability testing
- Paid distribution, direct download, or Mac App Store strategy
