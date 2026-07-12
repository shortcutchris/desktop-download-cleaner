# Research summary

Research captured on 2026-07-12. Recheck external behavior and API details during implementation because products and APIs evolve.

## Yoink

Yoink's current product already provides the temporary edge shelf originally considered for this project. Its official listing describes:

- a shelf at the screen edge for files and application content
- movement across windows, Spaces, and full-screen apps
- Quick Look-based icons and file stacks
- services, Quick Actions, Share extensions, Handoff, Shortcuts, and clipboard history
- extensive control over where and when the shelf appears

Sources:

- [Yoink in the Mac App Store](https://apps.apple.com/us/app/yoink-better-drag-and-drop/id457622435?mt=12)
- [Yoink 3.7 release article](https://blog.eternalstorms.at/2026/03/02/yoink-for-mac-v3-7-the-better-way-to-drag-and-drop/)
- [Yoink tips](https://eternalstorms.at/yoink/mac/tips/)

Product inference: rebuilding the shelf would compete with a mature, actively maintained utility and dilute the cleanup product. The cleaner should focus on accumulated files, planning, renaming, staging, rules, and undo.

## OpenAI API

The current OpenAI text generation guide recommends the Responses API for new text-generation applications. Structured Outputs can constrain model output to a supplied JSON Schema and is preferable to relying on loosely formatted JSON for machine actions.

Sources:

- [OpenAI text generation guide](https://developers.openai.com/api/docs/guides/text)
- [OpenAI Structured Outputs guide](https://developers.openai.com/api/docs/guides/structured-outputs)

Product inference: AI should return a narrow proposal object, not filesystem paths or commands. Local code remains responsible for sanitization, containment, collision handling, approval, and execution.

## API key safety

OpenAI recommends that application developers never embed or commit their own API key in a client application. For the initial personal/BYOK product, every user supplies their own key, which is stored only in macOS Keychain and can be deleted from Settings. A future consumer product with AI included would require a backend proxy, authentication, limits, and billing rather than a shared client-side key.

Source:

- [OpenAI API key safety](https://help.openai.com/en/articles/5112595-best-practices-for-api-key-safety)

