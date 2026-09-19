#!/bin/bash
# Builds Native Sheets and packages it as the disk image that gets published.
#
# AppKit needs a real bundle, not a bare binary: without Info.plist there is no
# menu bar, no document types and no Dock icon. The bundle is assembled here on
# the way into the image.
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
APP="$ROOT/build/Native Sheets.app"
STAGE="$ROOT/build/dmg"
# Next copies public/ into the exported site verbatim, so this path is the URL.
DMG="$REPO/landing/public/NativeSheets.dmg"

cd "$ROOT"
# Universal, so one download runs on Apple Silicon and on Intel.
swift build -c release --arch arm64 --arch x86_64
BIN_PATH="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

rm -rf "$APP" "$STAGE" "$DMG"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_PATH/XLSXEditor" "$APP/Contents/MacOS/Native Sheets"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi
printf 'APPL????' > "$APP/Contents/PkgInfo"

# An ad-hoc signature keeps macOS from quarantining the bundle on every launch.
codesign --force --deep --sign - "$APP"

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
