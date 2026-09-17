import type { ContentRecord } from "../types";

export const keepChartsWhenEditingXlsx: ContentRecord = {
  id: "keep-charts-when-editing-xlsx",
  slug: "keep-charts-when-editing-xlsx",
  type: "article",
  status: "published",
  title: "Why charts and pivot tables disappear when you edit someone else's workbook",
  description:
    "What is actually inside an .xlsx file, why a save in the wrong app strips charts, pivot caches and conditional formatting, and how to check whether your own workflow does it.",
  language: "en-US",
  intentCluster: "xlsx-round-trip-loss",
  authorId: "tashuk",
  datePublished: "2026-09-17",
  category: "Use case",
  relatedIds: ["open-xlsx-on-mac-without-excel", "round-trip-fidelity", "formula-coverage"],
  productOrToolId: "viewer",
  indexable: true,
  body: [
    {
      kind: "paragraph",
      content: [
        "You get a workbook, you fix two numbers, you send it back, and the reply is that the charts are gone. Nothing you did removed them. The save did, because most spreadsheet applications do not edit an .xlsx file so much as rebuild it from whatever they understood when they opened it.",
      ],
    },
    { kind: "heading", id: "inside", text: "What is actually inside the file" },
    {
      kind: "paragraph",
      content: [
        "An .xlsx file is a ZIP archive of XML parts. Rename one to ",
        { code: ".zip" },
        " and unzip it and you will see something close to this:",
      ],
    },
    {
      kind: "code",
      code: [
        "[Content_Types].xml",
        "_rels/.rels",
        "xl/workbook.xml",
        "xl/_rels/workbook.xml.rels",
        "xl/worksheets/sheet1.xml",
        "xl/worksheets/sheet2.xml",
        "xl/sharedStrings.xml",
        "xl/styles.xml",
        "xl/theme/theme1.xml",
        "xl/charts/chart1.xml",
        "xl/drawings/drawing1.xml",
        "xl/pivotCache/pivotCacheDefinition1.xml",
        "xl/tables/table1.xml",
        "docProps/app.xml",
      ].join("\n"),
    },
    {
      kind: "paragraph",
      content: [
        "The cells you edit live in ",
        { code: "xl/worksheets/sheetN.xml" },
        ". Everything else is context: the theme that decides what \"accent 1\" looks like, the chart definitions, the pivot cache that holds a snapshot of the source data, the table definitions that make a range behave like a table, the printer settings. None of that is data you typed, and all of it is data someone will notice missing.",
      ],
    },
    { kind: "heading", id: "why-lost", text: "Why a save loses it" },
    {
      kind: "paragraph",
      content: [
        "When an application opens a workbook, it parses the parts it models into an in-memory representation: sheets, rows, cells, styles. Parts it does not model are, from its point of view, not there. On save it serialises its model back out to a fresh ZIP. The output contains exactly what the model held, which is why the chart part is missing: nothing in the model ever represented it.",
      ],
    },
    {
      kind: "paragraph",
      content: [
        "This is not a bug anyone forgot to fix. It is the natural consequence of a model-and-serialise design, and it is why the same file can survive one application and not another. Applications also differ in the smaller direction: a round trip may keep the chart but lose a column width, a defined name, or the exact number format on one cell.",
      ],
    },
    {
      kind: "table",
      caption: "Two save strategies",
      head: ["", "Model-and-serialise", "Rewrite only what changed"],
      rows: [
        ["Parts written", "All of them, from the model", "Only the parts the editor models"],
        ["Parts not modelled", "Dropped", "Copied through byte for byte"],
        [
          "Risk",
          "Silent loss of charts, pivot caches, drawings, conditional formatting",
          "The editor must be honest about what it does not display",
        ],
      ],
    },
    { kind: "heading", id: "approach", text: "The approach Native Sheets takes" },
    {
      kind: "paragraph",
      content: [
        "Native Sheets keeps the raw bytes of every part it opened. On save it regenerates only ",
        { code: "workbook.xml" },
        ", the sheet parts, ",
        { code: "sharedStrings.xml" },
        ", ",
        { code: "[Content_Types].xml" },
        " and the workbook relationships, then copies everything else straight through. Themes, tables, pivot caches, charts, drawings and conditional formatting come back out byte for byte. ",
        { text: "The mechanics are described here", href: "/features/round-trip-fidelity/" },
        ".",
      ],
    },
    {
      kind: "note",
      title: "The honest limitation",
      content: [
        "Preserved is not the same as editable. Native Sheets does not display or edit charts, images, pivot tables or conditional formatting. It carries them; it does not show them. If you need to change a chart, you need an application that models charts.",
      ],
    },
    {
      kind: "paragraph",
      content: [
        "On the project's sample workbook, a 1.6 MB four-sheet tracker with 20,739 cells and 4,530 formulas, an open-and-save round trip left all 20,739 cells identical, and the result was cross-checked with openpyxl, an unrelated implementation, which reported no differences in values, styles, tables, column widths or frozen panes.",
      ],
    },
    { kind: "heading", id: "check-your-own", text: "Checking your own workflow" },
    {
      kind: "paragraph",
      content: [
        "You do not have to take anyone's word for which of your tools drops things. Compare the part listing before and after a save:",
      ],
    },
    {
      kind: "list",
      ordered: true,
      items: [
        [{ code: "cp book.xlsx before.xlsx" }, " to keep an untouched copy."],
        ["Open the workbook in the application you are testing, change one cell, save."],
        [
          "List the parts in each file with ",
          { code: "unzip -l before.xlsx" },
          " and ",
          { code: "unzip -l book.xlsx" },
          ", then compare the two listings.",
        ],
        [
          "Anything that appears in the first listing and not the second was dropped by that save.",
        ],
      ],
    },
    {
      kind: "code",
      language: "bash",
      code: "unzip -l before.xlsx | awk '{print $4}' | sort > /tmp/before.txt\nunzip -l book.xlsx   | awk '{print $4}' | sort > /tmp/after.txt\ndiff /tmp/before.txt /tmp/after.txt",
    },
    {
      kind: "paragraph",
      content: [
        "A missing ",
        { code: "xl/charts/" },
        " or ",
        { code: "xl/pivotCache/" },
        " line is your answer. Note that identical part names do not prove identical contents, so this checks for loss, not for fidelity. If you want to see which sheets and values survived, open both files in the ",
        { text: "browser viewer", href: "/viewer/" },
        " and compare them side by side.",
      ],
    },
  ],
};
