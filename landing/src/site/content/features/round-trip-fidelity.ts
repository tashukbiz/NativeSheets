import type { ContentRecord } from "../types";

export const roundTripFidelity: ContentRecord = {
  id: "round-trip-fidelity",
  slug: "round-trip-fidelity",
  type: "feature",
  status: "published",
  title: "Round-trip fidelity: saving without rewriting the whole file",
  description:
    "Native Sheets keeps the raw bytes of every part of an .xlsx package and regenerates only the parts it models, so charts, pivot caches and themes survive a save.",
  language: "en-US",
  intentCluster: "xlsx-round-trip-loss",
  authorId: "tashuk",
  datePublished: "2026-09-17",
  relatedIds: ["keep-charts-when-editing-xlsx", "formulas", "viewer"],
  indexable: true,
  body: [
    {
      kind: "paragraph",
      content: [
        "An .xlsx package usually contains more than the cells you can see. Native Sheets treats the parts it does not model as data to carry rather than data to discard.",
      ],
    },
    { kind: "heading", id: "how", text: "How it works" },
    {
      kind: "paragraph",
      content: [
        "The reader holds on to the raw bytes of every part it opened, in a ",
        { code: "PackageParts" },
        " structure that sits alongside the parsed workbook. On save, the writer regenerates only the parts it understands and copies the rest through unchanged:",
      ],
    },
    {
      kind: "table",
      head: ["Regenerated on save", "Copied through byte for byte"],
      rows: [
        ["workbook.xml", "Themes"],
        ["xl/worksheets/sheetN.xml", "Tables"],
        ["sharedStrings.xml", "Pivot caches"],
        ["[Content_Types].xml", "Charts and drawings"],
        ["The workbook relationships", "Conditional formatting, printer settings"],
      ],
    },
    { kind: "heading", id: "evidence", text: "What has been measured" },
    {
      kind: "paragraph",
      content: [
        "On the project's sample workbook, a 1.6 MB four-sheet tracker with 20,739 cells and 4,530 formulas, a read-write-read cycle produced 20,739 identical cells out of 20,739, and 4,530 of 4,530 formulas matched the values the file itself had cached. The saved file was also opened with openpyxl, an unrelated implementation, which reported no differences in values, styles, tables, column widths or frozen panes.",
      ],
    },
    {
      kind: "paragraph",
      content: [
        "The same check runs against any workbook you point it at, which is the only way to know about yours:",
      ],
    },
    {
      kind: "code",
      language: "bash",
      code: "XLSX_CHECK_SOURCE=~/book.xlsx swift test --filter ExternalWorkbookTests",
    },
    { kind: "heading", id: "limits", text: "Prerequisites and limits" },
    {
      kind: "list",
      items: [
        ["macOS 14 or later, and a Swift 6 toolchain (Xcode 16 or newer) to build the app."],
        [
          "Preserved is not editable. Charts, images, pivot tables and conditional formatting are carried through a save but are neither displayed nor edited.",
        ],
        [
          "A pivot cache is a snapshot taken when the workbook was last saved by an application that models pivot tables. Preserving it does not refresh it.",
        ],
      ],
    },
    {
      kind: "paragraph",
      content: [
        "If you want to see which parts your own files carry before deciding anything, ",
        { text: "this article walks through comparing a workbook before and after a save", href: "/blog/keep-charts-when-editing-xlsx/" },
        ".",
      ],
    },
  ],
};
