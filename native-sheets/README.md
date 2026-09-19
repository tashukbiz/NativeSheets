# Native Sheets

A macOS app that opens and edits `.xlsx` files. Free. No runtime to install. No third-party dependencies.

Download: https://tashukbiz.github.io/nativesheets/

## Requirements

- macOS 14 or later
- Apple Silicon or Intel. The app ships as a universal binary.
- To build: Swift 6 toolchain (Xcode 16 or later)

## Build

Build the disk image from the latest code:

```bash
git clone https://github.com/tashukbiz/nativesheets.git
cd nativesheets/native-sheets
./Scripts/make_dmg.sh
```

This makes `build/NativeSheets.dmg`, the published deliverable: the app next to
an Applications symlink, so installing is a drag. On an existing clone, run
`git pull` first. The binary is universal, and the script checks the signature
and prints the architectures when it finishes. The assembled bundle is left in
`build/Native Sheets.app` if you want to run it without installing.

## Features

- **Workbooks.** Add, rename, duplicate, reorder and delete sheets. Each sheet keeps its column widths, row heights, frozen panes, merges and tab colour.
- **Editing.** Type in a cell. Move with the arrow keys. Extend the selection with Shift. Insert and delete rows and columns. Undo every change. Copy and paste through the clipboard.
- **Formulas.** About 90 functions. Cross-sheet references, absolute and relative addressing, and wildcards in `COUNTIF`. The app recalculates only the cells that depend on the edit. It reports circular references.
- **Formatting.** Bold, italic, underline, alignment, wrapped text, merged cells and frozen panes. Number formats include dates, percentages and currency.
- **Dropdowns.** A cell with a value list shows a button. Press Option-Down to open it.
- **Fidelity.** The app keeps every part of the original file. A save rewrites only the parts the app models. Themes, tables, pivot caches, charts, drawings and conditional formatting stay unchanged.

## Limits

The app preserves charts, images, pivot tables and conditional formatting, but does not show or edit them. There is no find and replace, no sorting, no filtering and no cell comments. The app does not evaluate array formulas, `INDIRECT`, `OFFSET` or defined names. Defined names survive a save.

## Performance

Measured on a 1.6 MB workbook with 4 sheets, 20,739 cells and 4,530 formulas. Release build.

| Action | Time |
|---|---|
| Open | 0.09 s |
| Save | 0.11 s |
| Recalculate all | 0.41 s |

All 20,739 cells are identical after a save. All 4,530 formulas match the cached values in the file. `openpyxl` confirms the result.

## Tests

```bash
swift test
```

149 tests. Three are opt-in and need a file you supply:

```bash
XLSX_CHECK_SOURCE=~/book.xlsx swift test --filter ExternalWorkbookTests
```

## Layout

```
Sources/XLSXKit          file format, no AppKit
Sources/XLSXEditorCore   interface, as a library so tests can drive it
Sources/XLSXEditor       executable
Scripts/make_dmg.sh      builds the app and packages NativeSheets.dmg
landing/                 website, published to GitHub Pages
```
