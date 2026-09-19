import type { ContentRecord } from "../types";

export const formulaCoverage: ContentRecord = {
  id: "formula-coverage",
  slug: "will-my-formulas-work",
  type: "article",
  status: "published",
  title: "Will my formulas work? The functions Native Sheets evaluates, and the ones it does not",
  description:
    "The complete list of the 91 spreadsheet functions Native Sheets evaluates, what happens to a formula it cannot evaluate, and how to test your own workbook before you rely on it.",
  language: "en-US",
  intentCluster: "formula-support-decision",
  authorId: "tashuk",
  datePublished: "2026-09-17",
  category: "Decision",
  relatedIds: ["formulas", "keep-charts-when-editing-xlsx", "open-xlsx-on-mac-without-excel"],
  productOrToolId: "viewer",
  indexable: true,
  body: [
    {
      kind: "paragraph",
      content: [
        "Native Sheets evaluates 91 function names. If your workbook stays inside that list, editing a cell recalculates everything that depends on it, in dependency order. If it uses something outside the list, that is worth knowing before you commit to the app, so the whole list is below rather than a marketing summary of it.",
      ],
    },
    {
      kind: "note",
      title: "The one-line answer",
      content: [
        "Common arithmetic, aggregation, lookup, text and date work is covered. Array formulas, ",
        { code: "INDIRECT" },
        ", ",
        { code: "OFFSET" },
        " and defined names are not evaluated, and neither are newer dynamic-array functions such as ",
        { code: "XLOOKUP" },
        " or ",
        { code: "FILTER" },
        ".",
      ],
    },
    { kind: "heading", id: "supported", text: "The functions that are evaluated" },
    {
      kind: "table",
      caption: "Functions dispatched by the evaluator, as of 17 September 2026",
      head: ["Area", "Functions"],
      rows: [
        [
          "Maths",
          "ABS, CEILING, EXP, FLOOR, INT, LN, LOG, LOG10, MOD, PI, POWER, PRODUCT, RAND, RANDBETWEEN, ROUND, ROUNDDOWN, ROUNDUP, SIGN, SQRT, SUM, SUMIF, SUMIFS, TRUNC",
        ],
        [
          "Statistics",
          "AVERAGE, AVERAGEIF, COUNT, COUNTA, COUNTBLANK, COUNTIF, COUNTIFS, LARGE, MAX, MEDIAN, MIN, STDEV",
        ],
        [
          "Logic and information",
          "AND, FALSE, IF, IFERROR, IFNA, IFS, ISBLANK, ISERR, ISERROR, ISLOGICAL, ISNA, ISNUMBER, ISTEXT, NA, NOT, OR, SWITCH, TRUE, XOR",
        ],
        [
          "Text",
          "CHAR, CODE, CONCAT, EXACT, FIND, LEFT, LEN, LOWER, MID, PROPER, REPLACE, REPT, SUBSTITUTE, TEXT, TEXTJOIN, TRIM, UPPER, VALUE",
        ],
        [
          "Lookup and reference",
          "CHOOSE, COLUMN, HLOOKUP, INDEX, MATCH, ROW, ROWS, VLOOKUP",
        ],
        [
          "Dates and time",
          "DATE, DAY, DAYS, EDATE, HOUR, MINUTE, MONTH, NOW, SECOND, TODAY, YEAR",
        ],
      ],
    },
    {
      kind: "paragraph",
      content: [
        "Alongside the functions, the engine handles arithmetic and comparison operators, string concatenation with ",
        { code: "&" },
        ", ranges, absolute and relative addressing, cross-sheet references such as ",
        { code: "'Results'!$A$1" },
        ", and wildcard criteria in ",
        { code: "COUNTIF" },
        " and its relatives.",
      ],
    },
    { kind: "heading", id: "not-supported", text: "What is not evaluated" },
    {
      kind: "list",
      items: [
        [{ strong: "Array formulas." }, " Not evaluated."],
        [
          { strong: "INDIRECT and OFFSET." },
          " Not evaluated. Both build a reference at runtime, which the dependency graph is not designed to follow.",
        ],
        [
          { strong: "Defined names." },
          " Not evaluated, although they survive a save: a workbook that uses them keeps them, the formulas that reference them just do not recompute.",
        ],
        [
          { strong: "Anything outside the table above." },
          " Including XLOOKUP, SUMPRODUCT, FILTER, SEQUENCE, UNIQUE, SMALL, the financial functions, and COLUMNS (ROWS is present, COLUMNS is not).",
        ],
      ],
    },
    { kind: "heading", id: "what-happens", text: "What happens to a formula it cannot evaluate" },
    {
      kind: "paragraph",
      content: [
        "The formula text is part of the cell and is preserved through a save, so an unsupported formula is not destroyed by opening and saving the workbook. What you lose is recalculation: the cell keeps showing the value cached in the file by whichever application last computed it, and that value will not update when its inputs change in Native Sheets.",
      ],
    },
    {
      kind: "paragraph",
      content: [
        "That is a real hazard if you are editing inputs to an unsupported formula, because a stale number does not look stale. Circular references are a different case and are handled deliberately: they are detected and reported rather than looping.",
      ],
    },
    { kind: "heading", id: "testing", text: "Testing your own workbook" },
    {
      kind: "paragraph",
      content: [
        "The repository ships an opt-in test that recomputes every formula in a workbook you point it at and compares the results against the values already stored in the file. It is the most direct answer to \"does this handle my spreadsheet\":",
      ],
    },
    {
      kind: "code",
      language: "bash",
      code:
        "xcodebuild build-for-testing -scheme \"Native Sheets\" -derivedDataPath build/DerivedData\n" +
        "XLSX_CHECK_SOURCE=~/book.xlsx xcrun xctest -XCTest XLSXKitTests.ExternalWorkbookTests \\\n" +
        "  build/DerivedData/Build/Products/Debug/XLSXKitTests.xctest",
    },
    {
      kind: "paragraph",
      content: [
        "The same command also runs a round-trip check: it reads the file, writes it, reads it back, and compares every cell, formula, style, merge and frozen pane. On the project's sample workbook, a 1.6 MB four-sheet tracker, all 4,530 formulas matched the values the file had cached, and recalculating the whole workbook took 0.41 seconds in a release build.",
      ],
    },
    {
      kind: "paragraph",
      content: [
        "If you would rather not build anything first, the ",
        { text: "browser viewer", href: "/viewer/" },
        " shows the formula behind each cell, which is enough to find out which functions a workbook actually uses before you decide. ",
        { text: "How the engine recalculates", href: "/features/formulas/" },
        " covers the dependency ordering in more detail.",
      ],
    },
  ],
};
