# XLSX Editor, architecture

A standalone macOS spreadsheet editor for `.xlsx` files. No third-party
dependencies: the OOXML container, the XML, the formula engine and the grid are
all implemented in this repo against Foundation, Compression and AppKit.

## Why no dependencies

A `.xlsx` file is a ZIP archive of XML parts. macOS ships raw DEFLATE
(`Compression`) and a streaming XML parser (`XMLParser`), which is everything the
format needs. Avoiding SPM/CocoaPods dependencies keeps the result a single
self-contained `.app` with nothing to install.

## Layers

```
┌───────────────────────────────────────────────────┐
│ XLSXEditorApp   AppKit: NSDocument, grid, menus   │
├───────────────────────────────────────────────────┤
│ XLSXKit                                           │
│   Formula   tokenizer → parser → evaluator        │
│   Format    number-format codes → display strings │
│   Write     model → OOXML parts                   │
│   Read      OOXML parts → model                   │
│   Model     Workbook / Worksheet / Cell           │
│   XML       SAX reader, escaping writer           │
│   Zip       ZIP reader + writer over Compression  │
└───────────────────────────────────────────────────┘
```

`XLSXKit` has no AppKit import, so the whole file layer is unit-testable without
a UI.

### Zip

`ZipArchive` reads the end-of-central-directory record, walks the central
directory and inflates entries on demand. `ZipWriter` emits stored or deflated
entries with a CRC-32 computed from a generated table. Zip64 is read, and
written when an entry or the archive crosses the 4 GB / 65535-entry limits.

### XML

Worksheets can be tens of megabytes, so reading is event-based
(`XMLParser`, namespace processing on) rather than DOM. Prefix-agnostic by
construction: the sample workbook uses an `x:` prefix on every element, others
use a default namespace, and both parse to the same local names.

`XMLWriter` is a small string builder that escapes text and attributes. Writing
is done by hand rather than through a DOM to keep the memory profile flat on
large sheets.

### Model

```
Workbook
  ├─ sheets: [Worksheet]          ordered, mirrors the tab bar
  ├─ styles: WorkbookStyles       number formats, fonts, fills, borders, xfs
  └─ package: PackageParts        every original part, verbatim
Worksheet
  ├─ rows: [Int: Row]             sparse, 1-based
  ├─ columns: [ColumnSpan]        widths
  ├─ merges, freeze, tabColor
Cell
  ├─ value: .empty/.number/.string/.bool/.error
  ├─ formula: String?
  └─ styleIndex: Int
```

Cells are sparse: a workbook is a dictionary of populated rows, each a
dictionary of populated cells. The sample's 1268-row × 15-column sheet costs
what its real cells cost, and the grid can scroll to row 100 000 without
allocating anything.

### Round-trip fidelity

The reader keeps the raw bytes of **every** part it opened. On save, the writer
regenerates only the parts it understands (`workbook.xml`, `sheetN.xml`,
`sharedStrings.xml`, `[Content_Types].xml`, the workbook rels) and copies
everything else byte for byte: themes, styles, tables, pivot caches, drawings,
printer settings. Editing a cell in a workbook with charts does not throw the
charts away.

### Formula engine

A hand-written tokenizer and precedence-climbing parser produce an AST; the
evaluator walks it against the workbook. Supports arithmetic, comparison, string
concatenation, absolute/relative references, ranges, cross-sheet references
(`'Results'!$A$1`), and a function library (math, statistical, logical, text,
lookup, date).

Recalculation is dependency-ordered: each formula's precedents are collected at
parse time, and cells are evaluated in topological order with cycle detection,
so `A1 = B1 + 1` updates the moment `B1` changes. Values are cached; editing a
cell dirties only its dependents.

Relative references shift when rows or columns are inserted or deleted, and when
a formula is copied to another cell.

### Grid

`GridView` is a custom `NSView` that draws only the visible cell rectangle, so
scroll performance is independent of sheet size. It owns selection, keyboard
navigation, column and row resizing, and hands off to an overlaid `NSTextField`
for editing. Frozen panes are drawn as separate clipped regions over the same
model.

### Document

`SpreadsheetDocument` is an `NSDocument`, which gives open/save/save-as, the
recent-files menu, dirty-state tracking, autosave and revert for free. Every
mutation goes through a command applied to the document and registered with
`NSUndoManager`, so undo works uniformly across cell edits, row/column
operations and sheet operations.

## Staged build

1. ZIP reader/writer
2. XML layer
3. Model and reader
4. Writer and round-trip tests
5. Number formatting
6. Formula engine
7. Grid view
8. Editing, undo, row/column operations
9. Multi-sheet tab bar
10. Document, menus, `.app` packaging
