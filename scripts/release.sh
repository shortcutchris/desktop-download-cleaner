#!/bin/bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <version> <notarytool-keychain-profile>" >&2
  exit 64
fi

VERSION="$1"
NOTARY_PROFILE="$2"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/DesktopCleaner.xcodeproj"
SCHEME="DesktopCleaner"
ARTIFACTS="$ROOT/artifacts/$VERSION"
DERIVED_DATA="$ROOT/.build/ReleaseDerivedData"
RESULT_BUNDLE="$ROOT/.build/Release-$VERSION.xcresult"
ARCHIVE="$ARTIFACTS/DesktopCleaner-$VERSION.xcarchive"
APP="$ARCHIVE/Products/Applications/DesktopCleaner.app"
ZIP="$ARTIFACTS/DesktopCleaner-$VERSION.zip"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: Hans Christian Hubmann (UCCXC2RSU9)}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-UCCXC2RSU9}"

cd "$ROOT"

PROJECT_VERSION="$(awk '/MARKETING_VERSION:/ {gsub(/[\" ]/, "", $2); print $2; exit}' project.yml)"
if [[ "$PROJECT_VERSION" != "$VERSION" ]]; then
  echo "project.yml is version $PROJECT_VERSION, expected $VERSION" >&2
  exit 65
fi

rm -rf "$ARTIFACTS" "$RESULT_BUNDLE"
mkdir -p "$ARTIFACTS"

xcodegen generate
xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=-

xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  -resultBundlePath "$RESULT_BUNDLE" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=-

xcrun xcresulttool get test-results summary \
  --path "$RESULT_BUNDLE" \
  --format json > "$ARTIFACTS/test-summary.json"

xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"

codesign --verify --deep --strict --verbose=2 "$APP"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --wait --keychain-profile "$NOTARY_PROFILE"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
shasum -a 256 "$ZIP" > "$ZIP.sha256"

SPARKLE_GENERATE_APPCAST="${SPARKLE_GENERATE_APPCAST:-$(find "$ROOT/.build" -type f -path '*/Sparkle/bin/generate_appcast' -print -quit)}"
if [[ -z "$SPARKLE_GENERATE_APPCAST" ]]; then
  echo "Sparkle generate_appcast was not found. Resolve packages or set SPARKLE_GENERATE_APPCAST." >&2
  exit 66
fi

"$SPARKLE_GENERATE_APPCAST" \
  --download-url-prefix "https://github.com/shortcutchris/desktop-download-cleaner/releases/download/v$VERSION/" \
  "$ARTIFACTS"

echo "Release artifacts prepared in $ARTIFACTS"
echo "External publication still requires explicit authorization, CI success, merge, signed tag, asset upload, appcast verification, installation, and launch testing."
