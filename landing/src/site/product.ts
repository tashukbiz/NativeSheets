/**
 * Verified product facts. Every claim here is traceable to the app repository
 * (native-sheets/README.md, Resources/Info.plist, Package.swift).
 */
import { absoluteAssetUrl, assetPath } from "./urls";

export type Availability = "released" | "source-available" | "coming-soon" | "unavailable";

export interface ProductFacts {
  name: string;
  category: string;
  platform: string;
  minimumOS: string;
  architecture: string;
  price: string;
  availability: Availability;
  /** How a visitor can actually get the app today. */
  accessNote: string;
}

export const product: ProductFacts = {
  name: "Native Sheets",
  category: "Spreadsheet editor for .xlsx files",
  platform: "macOS",
  minimumOS: "macOS 14 or later",
  architecture: "Apple Silicon or Intel",
  price: "Free",
  availability: "released",
  accessNote:
    "The app is a free download. It is not on the App Store and it is not notarised, so macOS asks you to confirm the first launch.",
};

/**
 * The download. The image is committed to the repository under landing/public,
 * so the site serves it itself and a push is what publishes a new build.
 */
const downloadFile = "/NativeSheets.dmg";

export const download = {
  /** Href for a link on the site. Carries the base path already. */
  url: assetPath(downloadFile),
  /** Same file, absolute, for metadata that cannot use a relative path. */
  absoluteUrl: absoluteAssetUrl(downloadFile),
  repositoryUrl: "https://github.com/tashukbiz/nativesheets",
  fileName: "NativeSheets.dmg",
} as const;

/**
 * The app carries an ad-hoc signature rather than a Developer ID, so Gatekeeper
 * blocks the first launch. These are the steps that clear it.
 */
export const installSteps: string[] = [
  "Download the disk image and open it. macOS mounts it and shows Native Sheets beside a shortcut to Applications.",
  "Drag Native Sheets onto Applications, then eject the disk image.",
  "Open the app from Applications. macOS refuses the first launch because the app is not notarised.",
  "Go to System Settings, then Privacy & Security. Find the message about Native Sheets and select Open Anyway.",
  "Confirm. macOS remembers the choice, so later launches open directly.",
];

export interface Capability {
  id: string;
  title: string;
  summary: string;
  detail: string[];
  /** Optional dedicated page route for this capability. */
  route?: string;
}

export const capabilities: Capability[] = [
  {
    id: "round-trip",
    title: "Saves back what it does not understand",
    summary:
      "The reader keeps the raw bytes of every part of the original file. Saving regenerates only the parts the editor models.",
    detail: [
      "Themes, tables, pivot caches, charts, drawings and conditional formatting come back out of a save byte for byte.",
      "Only workbook.xml, the sheet parts, sharedStrings.xml, [Content_Types].xml and the workbook relationships are rewritten.",
      "Editing one cell in a workbook full of charts does not throw the charts away.",
    ],
    route: "/features/round-trip-fidelity/",
  },
  {
    id: "formulas",
    title: "A dependency-ordered formula engine",
    summary:
      "About 90 functions across maths, statistics, logic, text, lookup and dates, recalculated in dependency order.",
    detail: [
      "Cross-sheet references such as 'Results'!$A$1, absolute and relative addressing, and wildcard criteria in COUNTIF and friends.",
      "Editing a cell recalculates exactly what depends on it; circular references are detected and reported rather than looping.",
      "Relative references shift when rows or columns are inserted or deleted, and when a formula is copied.",
    ],
    route: "/features/formulas/",
  },
  {
    id: "workbooks",
    title: "Multi-sheet workbooks",
    summary:
      "Sheets appear as tabs along the bottom: add, rename, duplicate, reorder by dragging, and delete.",
    detail: [
      "Each sheet keeps its own column widths, row heights, frozen panes, merges and tab colour.",
      "The tab colour fills the tab the way a spreadsheet shows it.",
    ],
  },
  {
    id: "editing",
    title: "Keyboard editing with uniform undo",
    summary:
      "Arrow keys move, Shift-arrow extends, Command-arrow jumps to the edge of the data, Tab and Return move on after committing.",
    detail: [
      "Cut, copy and paste exchange tab-separated text with other spreadsheets through the clipboard.",
      "Rows and columns can be inserted and deleted, and header dividers dragged to resize.",
      "Every change is undoable, including structural ones.",
    ],
  },
  {
    id: "formatting",
    title: "Formatting and number formats",
    summary:
      "Bold, italic, underline, alignment, wrapped text, merged cells, frozen panes, and number formats including dates, percentages and currency.",
    detail: [
      "Typing 40% or 2026-09-16 applies the matching format on its own.",
      "A cell the file restricts to a list of values shows a disclosure button when selected; Option-Down opens the list.",
    ],
  },
  {
    id: "no-dependencies",
    title: "No runtime and no third-party dependencies",
    summary:
      "The ZIP container, the XML, the number formats, the formula engine and the grid are all implemented in the app's own repository.",
    detail: [
      "The app is built against Foundation, Compression and AppKit only.",
      "The result is a single self-contained .app bundle with nothing else to install.",
    ],
  },
];

/** Limitations, stated as plainly on the site as they are in the app's README. */
export const limitations: string[] = [
  "Charts, images, pivot tables and conditional formatting are preserved through a save but are neither displayed nor editable.",
  "There is no find and replace, no sorting or filtering, and no cell comments.",
  "Printing is only what NSDocument provides for free.",
  "Formula support is a wide subset rather than the whole of Excel's function list. Array formulas, INDIRECT, OFFSET and defined names are not evaluated, though defined names survive a save.",
  "The app runs on macOS 14 or later. It is a universal binary, so Apple Silicon and Intel Macs both run it, but there is no Windows, Linux, iOS or web build of the editor itself.",
  "The app is signed ad-hoc, not notarised by Apple. macOS blocks the first launch until you allow it in Privacy & Security.",
];

/**
 * Measurements published by the app repository for its sample workbook: a
 * 1.6 MB, four-sheet tracker with 20,739 cells and 4,530 formulas, release build.
 */
export const benchmark = {
  workbook: "1.6 MB, four sheets, 20,739 cells, 4,530 formulas",
  rows: [
    { label: "Open", value: "0.09 s" },
    { label: "Save", value: "0.11 s" },
    { label: "Recalculate everything", value: "0.41 s" },
    { label: "Cells identical after a save", value: "20,739 of 20,739" },
    { label: "Formulas matching the file's own cached values", value: "4,530 of 4,530" },
  ],
  note: "The round-trip was also checked with openpyxl, an unrelated implementation, which found no differences in values, styles, tables, column widths or frozen panes.",
} as const;

export interface Tool {
  id: string;
  name: string;
  route: string;
  summary: string;
}

/** The free browser experience. It is the site's primary action. */
export const tools: Tool[] = [
  {
    id: "viewer",
    name: "XLSX viewer",
    route: "/viewer/",
    summary:
      "Open an .xlsx workbook in this browser tab, read every sheet, and export a sheet as CSV. The file never leaves the device.",
  },
];

export const buildCommand = "./Scripts/make_dmg.sh";
