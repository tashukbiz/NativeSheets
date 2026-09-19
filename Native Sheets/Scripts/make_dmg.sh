#!/bin/bash
# Builds Native Sheets and packages it as the disk image that gets published.
#
# A DMG is what macOS expects for an app distributed outside the App Store: it
# mounts read only, so the app is copied out rather than run from the download,
# and the Applications symlink turns that copy into a drag.
#
# Releasing is manual: the image is written into the site's public/ directory and
# committed, so pushing it is what publishes it. Nothing builds the app in CI.
set -euo pipefail

# $0, not BASH_SOURCE: the latter is unset when the script is handed to another
# shell (zsh ./Scripts/make_dmg.sh), and under set -u that resolves ROOT to /.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$ROOT/.." && pwd)"
DERIVED="$ROOT/build/DerivedData"
APP="$DERIVED/Build/Products/Release/Native Sheets.app"
STAGE="$ROOT/build/dmg"
# Next copies public/ into the exported site verbatim, so this path is the URL.
DMG="$REPO/landing/public/NativeSheets.dmg"

rm -rf "$STAGE" "$DMG"

# ONLY_ACTIVE_ARCH=NO makes this universal, so one download runs on Apple
# Silicon and on Intel. The project signs ad-hoc, which is all an unnotarised
# build can do and all it needs to stop macOS quarantining it on every launch.
xcodebuild \
    -project "$ROOT/Native Sheets.xcodeproj" \
    -scheme "Native Sheets" \
    -configuration Release \
    -derivedDataPath "$DERIVED" \
    ONLY_ACTIVE_ARCH=NO \
    build

mkdir -p "$STAGE"
# ditto, not cp: it keeps the bundle layout and the signature intact.
ditto "$APP" "$STAGE/Native Sheets.app"
ln -s /Applications "$STAGE/Applications"

hdiutil create -volname "Native Sheets" -srcfolder "$STAGE" -format ULFO -ov "$DMG" >/dev/null
rm -rf "$STAGE"

codesign --verify --deep --strict "$APP"
lipo -archs "$APP/Contents/MacOS/Native Sheets"
echo "Built $DMG"
echo "Commit landing/public/NativeSheets.dmg and push to publish it."
