import type { ContentRecord } from "../types";

export const openXlsxOnMacWithoutExcel: ContentRecord = {
  id: "open-xlsx-on-mac-without-excel",
  slug: "open-xlsx-on-mac-without-excel",
  type: "article",
  status: "published",
  title: "How to open and edit an .xlsx file on a Mac without Excel",
  description:
    "Four ways to open a .xlsx workbook on macOS without a Microsoft 365 subscription, what each one changes about the file, and how to check a workbook in the browser first.",
  language: "en-US",
  intentCluster: "open-xlsx-mac-no-excel",
  authorId: "tashuk",
  datePublished: "2026-09-17",
  category: "How-to",
  relatedIds: ["keep-charts-when-editing-xlsx", "formula-coverage", "viewer"],
  productOrToolId: "viewer",
  indexable: true,
  body: [
    {
      kind: "paragraph",
      content: [
        "The short answer: macOS can already show you what is inside an .xlsx file, and you have four practical ways to edit one without paying for Excel. Which one to pick depends on whether you need to keep the file byte-identical for someone else's tooling, or you only need to read a few numbers.",
      ],
    },
    {
      kind: "paragraph",
      content: [
        "If you only need to look at the data right now, open the workbook in the ",
        { text: "browser viewer on this site", href: "/viewer/" },
        ". It parses the file in the page, so nothing is uploaded, and it takes about as long as a double-click.",
      ],
    },
    { kind: "heading", id: "options", text: "The four options, compared" },
    {
      kind: "table",
      caption: "Ways to open an .xlsx workbook on macOS without Excel",
      head: ["Option", "Editing", "What it does to the file"],
      rows: [
        [
          "Quick Look (select the file, press Space)",
          "None",
          "Nothing. It renders a preview of the first sheets and never writes.",
        ],
        [
          "Numbers (Apple)",
          "Full, in Numbers' own model",
          "Imports into a .numbers document. Exporting back to .xlsx rebuilds the file, so parts Numbers does not model are not preserved.",
        ],
        [
          "LibreOffice Calc",
          "Full",
          "Reads and writes .xlsx directly. It rewrites the whole package on save, so the bytes of untouched parts change.",
        ],
        [
          "Native Sheets",
          "Cells, formulas, formatting, rows, columns and sheets",
          "Rewrites only the parts it models and copies every other part of the original package through unchanged.",
        ],
      ],
    },
    {
      kind: "paragraph",
      content: [
        "Quick Look and the browser viewer are read-only, which is the right answer more often than people expect. A large share of \"I need Excel\" moments are really \"I need to read column F\".",
      ],
    },
    { kind: "heading", id: "quick-look", text: "Reading a workbook without opening anything" },
    {
      kind: "list",
      ordered: true,
      items: [
        ["Select the .xlsx file in Finder."],
        ["Press Space for Quick Look, or press Option-Space for a full-screen preview."],
        ["Use the sheet tabs at the bottom of the preview to move between sheets."],
      ],
    },
    {
      kind: "paragraph",
      content: [
        "Quick Look renders what the file already contains. It does not recalculate formulas: what you see for a formula cell is the value the last program to save the file cached there. That distinction matters if someone sends you a workbook they edited in a tool that does not recalculate.",
      ],
    },
    { kind: "heading", id: "browser", text: "Checking a workbook in the browser first" },
    {
      kind: "paragraph",
      content: [
        "The ",
        { text: "XLSX viewer", href: "/viewer/" },
        " on this site reads the ZIP container and the sheet XML in the browser tab. It shows every sheet, the cell values, the formula behind a cell when there is one, and it exports any sheet as CSV. There is no upload step and no account, so it is a reasonable way to check a file from a stranger before you open it in anything with more privileges.",
      ],
    },
    {
      kind: "note",
      title: "What the viewer will not do",
      content: [
        "It reads; it does not edit or save. It shows cached formula results rather than recalculating them, and it does not render charts, images or conditional formatting. For editing on macOS you still need an app.",
      ],
    },
    { kind: "heading", id: "editing", text: "Editing without changing the rest of the file" },
    {
      kind: "paragraph",
      content: [
        "Every .xlsx file is a ZIP archive of XML parts: one part per worksheet, plus shared strings, styles, and whatever else the producing application wrote, such as chart definitions, pivot caches, drawings and printer settings. When a spreadsheet application saves, it usually regenerates the whole package from its own in-memory model. Anything it did not model is gone.",
      ],
    },
    {
      kind: "paragraph",
      content: [
        "That is the specific problem ",
        { text: "Native Sheets", href: "/" },
        " was built around. Its reader keeps the raw bytes of every part it opened. On save it regenerates only ",
        { code: "workbook.xml" },
        ", the sheet parts, ",
        { code: "sharedStrings.xml" },
        ", ",
        { code: "[Content_Types].xml" },
        " and the workbook relationships, and copies everything else through byte for byte. ",
        { text: "How that works in detail", href: "/features/round-trip-fidelity/" },
        " is worth reading if you are the person who has to hand the file back.",
      ],
    },
    { kind: "heading", id: "getting-the-app", text: "Getting Native Sheets today" },
    {
      kind: "paragraph",
      content: [
        "Native Sheets is free and has no third-party dependencies. ",
        {
          text: "Download it",
          href: "https://github.com/tashukbiz/NativeSheets/releases/latest/download/NativeSheets.dmg",
          external: true,
        },
        " and drag the app from the disk image to your Applications folder. It needs macOS 14 or later, on Apple Silicon or Intel.",
      ],
    },
    {
      kind: "paragraph",
      content: [
        "The app is signed ad-hoc rather than notarised by Apple, so macOS refuses the first launch. To clear it, open System Settings, go to Privacy & Security, find the message about Native Sheets and select Open Anyway. macOS remembers the choice.",
      ],
    },
    {
      kind: "paragraph",
      content: [
        "You can also build it yourself. This needs a Swift 6 toolchain (Xcode 16 or newer):",
      ],
    },
    {
      kind: "code",
      language: "bash",
      code: "./Scripts/make_app.sh\nopen \"build/Native Sheets.app\" your-workbook.xlsx",
    },
    { kind: "heading", id: "questions", text: "Common questions" },
    {
      kind: "faq",
      items: [
        {
          question: "Will opening a file in Numbers change it?",
          answer: [
            "Opening does not. Numbers imports the workbook into its own document format; the original .xlsx on disk is untouched until you export back over it. The export is a rebuild, not an edit of the original package.",
          ],
        },
        {
          question: "Can I edit an .xlsx file in the browser viewer here?",
          answer: [
            "No. The viewer reads workbooks only. Editing and saving happen in the macOS app.",
          ],
        },
        {
          question: "Do I need to be online?",
          answer: [
            "The macOS app works on local files and has no account, no sync and no upload step. The browser viewer needs the page to load once; the parsing itself then runs in the tab.",
          ],
        },
      ],
    },
  ],
};
