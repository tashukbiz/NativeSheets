#!/bin/bash
# Packages a notarised Native Sheets build as the zip that gets published.
#
# A zip rather than a disk image: this project signs with a cloud managed
# Developer ID certificate, whose private key stays at Apple, so codesign cannot
# sign an image locally, and an unsigned image is refused by Gatekeeper on
# download. A zip needs no signature of its own. The ticket stapled to the app
# inside is what Gatekeeper reads, so the app opens offline with no detour
# through Privacy & Security.
#
# Releasing is manual: the zip is written into the site's public/ directory and
# committed, so pushing it is what publishes it. Nothing builds the app in CI.
#
# The input is the app Xcode produced from Archive, Distribute App, Direct
# Distribution, Export. Notarisation has to have finished first.
set -euo pipefail

# $0, not BASH_SOURCE: the latter is unset when the script is handed to another
# shell (zsh ./Scripts/make_zip.sh), and under set -u that resolves ROOT to /.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$ROOT/.." && pwd)"
STAGE="$ROOT/build/zip"
# Next copies public/ into the exported site verbatim, so this path is the URL.
ZIP="$REPO/landing/public/NativeSheets.zip"

SOURCE="${1:-}"
if [ -z "$SOURCE" ] || [ ! -d "$SOURCE" ]; then
    echo "usage: $0 \"/path/to/exported/Native Sheets.app\"" >&2
    echo >&2
    echo "In Xcode: Product, Archive, then Distribute App, Direct Distribution." >&2
    echo "Wait for notarisation to finish, then Export, and pass that app here." >&2
    exit 1
fi

rm -rf "$STAGE" "$ZIP"
mkdir -p "$STAGE"
# ditto, not cp: it keeps the bundle layout and the signature intact.
ditto "$SOURCE" "$STAGE/Native Sheets.app"
APP="$STAGE/Native Sheets.app"

# Attaches the notarisation ticket so the app opens without the network. The
# ticket is fetched anonymously, so this needs no credentials.
xcrun stapler staple "$APP"

codesign --verify --deep --strict "$APP"
# Captured rather than piped into grep: under pipefail, grep -q closing the pipe
# early kills codesign with SIGPIPE and fails the check on a good build.
SIGNATURE="$(codesign -dvv "$APP" 2>&1)"
case "$SIGNATURE" in
    *"flags="*"(runtime"*) ;;
    *) echo "error: hardened runtime is off, so this build cannot be notarised" >&2; exit 1 ;;
esac
case "$SIGNATURE" in
    *"Authority=Developer ID Application"*) ;;
    *) echo "error: not signed with Developer ID, so Gatekeeper will refuse it" >&2; exit 1 ;;
esac
spctl -a -t exec "$APP"
xcrun stapler validate "$APP"

# ditto -c -k --keepParent is the only zip that preserves the bundle's symlinks,
# its resource forks and the stapled ticket.
ditto -c -k --keepParent "$APP" "$ZIP"

ARCHITECTURES="$(lipo -archs "$APP/Contents/MacOS/Native Sheets")"
rm -rf "$STAGE"

echo "$ARCHITECTURES"
echo "Built $ZIP"
echo "Commit landing/public/NativeSheets.zip and push to publish it."
