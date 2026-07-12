# Release procedure

External releases require explicit authorization. Never commit signing, notarization, Sparkle, or API credentials.

## Prerequisites

- Clean release branch and successful `DesktopCleaner` scheme build/test.
- Developer ID Application identity installed in Keychain.
- Hardened runtime and app sandbox enabled.
- `notarytool` Keychain profile configured locally.
- Sparkle EdDSA private key available only in the local Keychain.
- Repository visibility and release-asset URLs compatible with the configured Sparkle feed.

## Reproducible checklist

1. Update `MARKETING_VERSION`, increment `CURRENT_PROJECT_VERSION`, changelog, and `release-notes/<version>.md`.
2. Regenerate the Xcode project with `xcodegen generate`.
3. Build and run the complete test suite with the shared scheme; record exact counts.
4. Archive with `Developer ID Application`, export the app, and verify `codesign --verify --deep --strict --verbose=2` plus `spctl --assess --type execute --verbose=2`.
5. Zip the signed app with `ditto -c -k --keepParent`, submit it with `xcrun notarytool submit --wait --keychain-profile <profile>`, then staple and validate the ticket.
6. Create the release DMG/ZIP and generate a signed Sparkle appcast with Sparkle's `generate_appcast` tool.
7. Commit through a focused pull request, wait for successful CI, merge, and create the signed `v<version>` tag.
8. Publish the GitHub release and upload the notarized app plus appcast.
9. Download the published asset, verify its checksum, signature, notarization ticket, and appcast enclosure/signature.
10. Install into `/Applications`, launch it, run a safe demo stage/undo, and test the Sparkle update path from the prior version.

The local build-through-appcast steps are automated by:

```sh
scripts/release.sh 1.0.0 <notarytool-keychain-profile>
```

The script reads signing and notarization credentials only through the local Keychain/toolchain. It prepares artifacts but intentionally does not commit, tag, push, merge, or publish them.

The current repository is private, so its GitHub release assets are not a public Sparkle feed. Keep automatic checks disabled until distribution visibility and the signed appcast URL are deliberately approved.
