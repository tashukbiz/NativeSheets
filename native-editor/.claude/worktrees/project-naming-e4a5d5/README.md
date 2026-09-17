# XLSX Editor

A spreadsheet editor for `.xlsx` files, as a standalone macOS app. No runtime to
install and no third-party dependencies: the ZIP container, the XML, the number
formats, the formula engine and the grid are all in this repository.

## Building

```bash
./Scripts/make_app.sh
```

That produces `build/Native Sheets.app`. Double-click it, or:

```bash
open "build/Native Sheets.app" your-workbook.xlsx
```

Requires macOS 14 or later and a Swift 6 toolchain (Xcode 16+).

## What it does

**Multi-page workbooks.** Sheets appear as tabs along the bottom. Add, rename
(double-click the tab), duplicate, reorder by dragging, and delete. Each sheet
keeps its own column widths, row heights, frozen panes, merges and tab colour,
which fills the tab the way a spreadsheet shows it.

**Editing.** Type into a cell, or press Return or F2 to edit an existing value.
Arrow keys move, Shift-arrow extends the selection, Command-arrow jumps to the
edge of the data, Tab and Return move on after committing. Cut, copy and paste
work with other spreadsheets through the clipboard's tab-separated format.
Insert and delete rows and columns; drag the header dividers to resize. Every
change is undoable, including structural ones.

**Formulas.** About 90 functions across maths, statistics, logic, text, lookup
and dates, with cross-sheet references (`'Results'!$A$1`), absolute and relative
addressing, and wildcard criteria in `COUNTIF` and friends. Editing a cell
recalculates exactly what depends on it, in dependency order; circular
references are detected and reported rather than looping.

**Formatting.** Bold, italic, underline, alignment, wrapped text, merged cells,
frozen panes, and number formats including dates, percentages and currency.
Typing `40%` or `2026-09-16` applies the matching format on its own.

**Dropdowns.** A cell the file restricts to a list of values shows a disclosure
button when selected. Click it, or press Option-Down, to pick from the list.

**It keeps what it does not understand.** The reader holds on to every part of
the original file, and saving regenerates only the parts the editor models.
Themes, tables, pivot caches, charts, drawings and conditional formatting come
back out of a save byte for byte.

## Checking it against your own files

Two opt-in tests run against any workbook you point them at:

```bash
XLSX_CHECK_SOURCE=~/book.xlsx swift test --filter ExternalWorkbookTests
```

The first reads the file, writes it, reads it back and compares every cell,
formula, style, merge and frozen pane. The second recomputes every formula and
checks the results against the values already stored in the file.

To see how a workbook renders, without opening the app:

```bash
XLSX_RENDER_SOURCE=~/book.xlsx XLSX_RENDER_OUTPUT=/tmp \
  swift test --filter RenderSnapshotTests
```

That writes a PNG per sheet, scrolled and unscrolled.

## Tests

```bash
swift test
```

149 tests, of which three are the opt-in checks above. `XLSXKitTests` covers the
file layer with no UI: the ZIP container is checked in both directions against
the system `zip` and `unzip`, and workbooks are built in memory under both XML
namespace conventions producers use.
`XLSXEditorCoreTests` drives the real views with synthesized mouse and keyboard
events and renders them offscreen, so selection, editing, undo and drawing are
all covered without launching the app.

## Measured on the sample workbook

A 1.6 MB, four-sheet tracker with 20 739 cells and 4 530 formulas, release
build:

| | |
|---|---|
| Open | 0.09 s |
| Save | 0.11 s |
| Recalculate everything | 0.41 s |
| Cells identical after a save | 20 739 of 20 739 |
| Formulas matching the file's own cached values | 4 530 of 4 530 |

The round-trip was also checked with `openpyxl`, an unrelated implementation,
which found no differences in values, styles, tables, column widths or frozen
panes.

## Limits

Reading covers more than editing does. Charts, images, pivot tables and
conditional formatting are preserved through a save but are neither displayed
nor editable. There is no printing beyond what `NSDocument` provides for free,
no find and replace, no sorting or filtering, and no cell comments. Formula
support is a wide subset rather than the whole of Excel's function list: array
formulas, `INDIRECT`, `OFFSET` and defined names are not evaluated, though
defined names survive a save.

## Layout

See [ARCHITECTURE.md](ARCHITECTURE.md) for how the pieces fit together.

```
Sources/XLSXKit          the file format, with no AppKit
Sources/XLSXEditorCore   the interface, as a library so tests can drive it
Sources/XLSXEditor       the executable, which is only a main.swift
Scripts/make_app.sh      assembles the .app bundle
```
