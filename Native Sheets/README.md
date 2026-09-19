# Native Sheets

A macOS app that opens and edits `.xlsx` files. Free. No runtime to install. No third-party dependencies.

Download: https://tashukbiz.github.io/nativesheets/

## Requirements

- macOS 14 or later
- Apple Silicon or Intel. The app ships as a universal binary.
- To build: Xcode 26 or later

## Build

To work on the app, open `Native Sheets.xcodeproj` and press Run. That is all
day-to-day development needs.

## Release

Releasing takes Xcode, because the Developer ID certificate this project signs
with is cloud managed: its private key stays at Apple, so only Xcode's export
can use it.

1. **Product, Archive.**
2. In the Organizer, **Distribute App**, then **Direct Distribution**. Xcode
   signs with the Developer ID certificate and uploads the app to Apple's
   notary service.
3. Wait for notarisation to come back. Apple emails, and the Organizer shows
   the state next to the archive.
4. **Export** the notarised app, then package it:

```bash
cd "Native Sheets"
./Scripts/make_zip.sh "path/to/exported/Native Sheets.app"
```

The script staples the notarisation ticket to the app, checks that the bundle
is Developer ID signed, has the hardened runtime and passes Gatekeeper, then
writes `landing/public/NativeSheets.zip` and prints the architectures.

A zip rather than a disk image: an image has to carry its own signature to get
past Gatekeeper on download, and the cloud managed certificate cannot sign one
locally. A zip needs no signature. The stapled ticket inside is what Gatekeeper
reads, so the app opens offline with no trip through Privacy & Security.

The zip lands inside the site because the site is what serves it. Committing
`landing/public/NativeSheets.zip` and pushing to `main` is the release: the
Pages workflow redeploys, and the download link on the page picks the new file
up with no further step. There is no version tag, no release page, and nothing
in CI builds the app, so every published binary is one that was built and
checked on a Mac first.

## Features

- **Workbooks.** Add, rename, duplicate, reorder and delete sheets. Each sheet keeps its column widths, row heights, frozen panes, merges and tab colour.
- **Editing.** Type in a cell. Move with the arrow keys. Extend the selection with Shift. Insert and delete rows and columns. Undo every change. Copy and paste through the clipboard.
- **Formulas.** About 90 functions. Cross-sheet references, absolute and relative addressing, and wildcards in `COUNTIF`. The app recalculates only the cells that depend on the edit. It reports circular references.
- **Formatting.** Bold, italic, underline, alignment, wrapped text, merged cells and frozen panes. Number formats include dates, percentages and currency.
- **Dropdowns.** A cell with a value list shows a button. Press Option-Down to open it.
- **Fidelity.** The app keeps every part of the original file. A save rewrites only the parts the app models. Themes, tables, pivot caches, charts, drawings and conditional formatting stay unchanged.

## Limits

The app preserves charts, images, pivot tables and conditional formatting, but does not show or edit them. There is no find and replace, no sorting, no filtering and no cell comments. The app does not evaluate array formulas, `INDIRECT`, `OFFSET` or defined names. Defined names survive a save.

## Tests

```bash
xcodebuild test -scheme "Native Sheets" -derivedDataPath build/DerivedData
```

149 tests across `XLSXKitTests` and `XLSXEditorCoreTests`. Three are opt-in and
need a file you supply. `xcodebuild` does not pass the shell environment to the
test process, so those take `xctest` directly:

```bash
xcodebuild build-for-testing -scheme "Native Sheets" -derivedDataPath build/DerivedData
XLSX_CHECK_SOURCE=~/book.xlsx xcrun xctest -XCTest XLSXKitTests.ExternalWorkbookTests \
  "build/DerivedData/Build/Products/Debug/XLSXKitTests.xctest"
```

`XLSX_RENDER_SOURCE` works the same way against
`XLSXEditorCoreTests.RenderSnapshotTests`, and writes PNGs of every sheet to
`XLSX_RENDER_OUTPUT` (the temporary directory by default).
