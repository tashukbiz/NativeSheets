#!/bin/bash
# Assembles Native Sheets.app from the SwiftPM executable.
#
# AppKit needs a real bundle, not a bare binary: without Info.plist there is no
# menu bar, no document types and no Dock icon.
set -euo pipefail

CONFIGURATION="${1:-release}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/Native Sheets.app"

# A release build is universal, so one download runs on Apple Silicon and on
# Intel. A debug build stays on the host architecture, which is half the work.
ARCHS="--arch arm64 --arch x86_64"
[ "$CONFIGURATION" = "release" ] || ARCHS=""

cd "$ROOT"
swift build -c "$CONFIGURATION" $ARCHS
BIN_PATH="$(swift build -c "$CONFIGURATION" $ARCHS --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_PATH/XLSXEditor" "$APP/Contents/MacOS/Native Sheets"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi
printf 'APPL????' > "$APP/Contents/PkgInfo"

# An ad-hoc signature is enough to run locally and keeps macOS from quarantining
# the bundle on every launch.
codesign --force --deep --sign - "$APP" 2>/dev/null || echo "note: could not sign the bundle"

echo "Built $APP"
