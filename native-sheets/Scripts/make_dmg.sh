#!/bin/bash
# Builds Native Sheets.app and packages it as the disk image that gets published.
#
# A DMG is what macOS expects for an app distributed outside the App Store: it
# mounts read only, so the app is copied out rather than run from the download,
# and the Applications symlink turns that copy into a drag.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/Native Sheets.app"
DMG="$ROOT/build/NativeSheets.dmg"
STAGE="$ROOT/build/dmg"

"$ROOT/Scripts/make_app.sh" release

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
# ditto, not cp: it keeps the bundle layout and the signature intact.
ditto "$APP" "$STAGE/Native Sheets.app"
ln -s /Applications "$STAGE/Applications"

hdiutil create -volname "Native Sheets" -srcfolder "$STAGE" -format ULFO -ov "$DMG" >/dev/null
rm -rf "$STAGE"

codesign --verify --deep --strict "$APP"
lipo -archs "$APP/Contents/MacOS/Native Sheets"
echo "Built $DMG"
