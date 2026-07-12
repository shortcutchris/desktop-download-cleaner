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

## Open decisions for later milestones

- Final product name and bundle identifier
- Final icon direction
- Whether move or copy should remain the default after usability testing
- Exact supported macOS baseline after dependency validation
- Paid distribution, direct download, or Mac App Store strategy

