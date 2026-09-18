import type { ContentRecord } from "../types";

/** The static explanation rendered around the interactive viewer. */
export const viewerTool: ContentRecord = {
  id: "viewer",
  slug: "viewer",
  type: "tool",
  status: "published",
  title: "XLSX viewer: open a spreadsheet in your browser",
  description:
    "Open an .xlsx workbook in this browser tab, read every sheet, see the formula behind a cell, and export a sheet as CSV. The file is parsed on your device and is never uploaded.",
  language: "en-US",
  intentCluster: "open-xlsx-online",
  authorId: "tashuk",
  datePublished: "2026-09-17",
  relatedIds: ["open-xlsx-on-mac-without-excel", "formula-coverage", "round-trip-fidelity"],
  productOrToolId: "viewer",
  indexable: true,
  body: [
    { kind: "heading", id: "how-to-use", text: "How to use it" },
    {
      kind: "list",
      ordered: true,
      items: [
        ["Choose a file, or drag an .xlsx workbook onto the drop area above."],
        ["Pick a sheet from the tabs. Sheet names come from the workbook itself."],
        ["Click a cell to see its address, its stored value and its formula if it has one."],
        ["Use the CSV button to download the sheet you are looking at."],
      ],
    },
    { kind: "heading", id: "what-it-reads", text: "What it reads" },
    {
      kind: "list",
      items: [
        ["Every worksheet in the workbook, in the order the workbook defines."],
        ["Cell values: numbers, text (inline and shared strings), booleans and error values."],
        ["The formula text stored in a cell, alongside the value cached with it."],
        ["Dates, shown in ISO form when the cell's number format is a date format."],
      ],
    },
    { kind: "heading", id: "limits", text: "Limits" },
    {
      kind: "list",
      items: [
        [
          { strong: "It does not recalculate." },
          " A formula cell shows the value the last application to save the file stored there. If that value was stale in the file, it is stale here.",
        ],
        [
          { strong: "It does not edit or save." },
          " Editing happens in the macOS app.",
        ],
        [
          { strong: "It does not render charts, images or conditional formatting." },
          " Those parts are in the file; this viewer does not draw them.",
        ],
        [
          { strong: "Formatting is not reproduced." },
          " Fonts, fills, borders and column widths are ignored; the grid is plain.",
        ],
        [
          { strong: "Large workbooks take memory." },
          " The whole file is decompressed in the tab, and very large sheets are displayed up to a bounded number of rows.",
        ],
        [
          { strong: "It needs JavaScript." },
          " The explanation on this page does not, but the viewer itself does.",
        ],
        [
          { strong: ".xls and .csv are not supported." },
          " The viewer reads the .xlsx (OOXML) format only.",
        ],
      ],
    },
    { kind: "heading", id: "privacy", text: "Where your file goes" },
    {
      kind: "paragraph",
      content: [
        "Nowhere. The workbook is read with the browser's own file API and decompressed in the page. No part of it is sent to a server, and this site has no server to send it to: it is a set of static files. Closing the tab discards everything. The ",
        { text: "privacy page", href: "/privacy/" },
        " says the same thing in more detail.",
      ],
    },
    { kind: "heading", id: "next", text: "If you need to edit" },
    {
      kind: "paragraph",
      content: [
        "Native Sheets is a free macOS app that edits .xlsx files and preserves the parts of the package it does not model. You can download it for macOS 14 or later on Apple Silicon. ",
        { text: "What it does and what it does not do", href: "/" },
        " is on the home page.",
      ],
    },
  ],
};
