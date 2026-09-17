import type { ContentRecord } from "../types";

export const formulasFeature: ContentRecord = {
  id: "formulas",
  slug: "formulas",
  type: "feature",
  status: "published",
  title: "The formula engine: dependency-ordered recalculation",
  description:
    "How Native Sheets parses, orders and recalculates formulas, what it does with circular references, and how references shift when rows and columns move.",
  language: "en-US",
  intentCluster: "formula-support-decision",
  authorId: "tashuk",
  datePublished: "2026-09-17",
  relatedIds: ["formula-coverage", "round-trip-fidelity", "viewer"],
  indexable: true,
  body: [
    {
      kind: "paragraph",
      content: [
        "Editing a cell recalculates exactly what depends on it, and nothing else. That is the whole design goal of the formula engine, and it is what keeps a large workbook responsive while you type in it.",
      ],
    },
    { kind: "heading", id: "pipeline", text: "Tokenizer, parser, evaluator" },
    {
      kind: "paragraph",
      content: [
        "A hand-written tokenizer and a precedence-climbing parser turn formula text into a syntax tree. The evaluator walks that tree against the workbook, resolving arithmetic, comparison, string concatenation, ranges, absolute and relative references, cross-sheet references such as ",
        { code: "'Results'!$A$1" },
        ", and a library of ",
        { text: "91 functions", href: "/blog/will-my-formulas-work/" },
        ".",
      ],
    },
    { kind: "heading", id: "ordering", text: "Dependency ordering" },
    {
      kind: "paragraph",
      content: [
        "Each formula's precedents are collected at parse time, so the workbook knows which cells feed which. Recalculation evaluates cells in topological order, with cycle detection, and values are cached. Editing a cell dirties only its dependents.",
      ],
    },
    {
      kind: "paragraph",
      content: [
        "A worked example. Given ",
        { code: "B1 = 4" },
        ", ",
        { code: "C1 = B1 * 2" },
        " and ",
        { code: "D1 = C1 + B1" },
        ", typing ",
        { code: "10" },
        " into B1 marks C1 and D1 dirty, evaluates C1 first because D1 depends on it, and leaves every unrelated cell in the workbook untouched. A circular reference, such as ",
        { code: "A1 = A1 + 1" },
        ", is detected and reported rather than looping.",
      ],
    },
    { kind: "heading", id: "references", text: "References that move" },
    {
      kind: "paragraph",
      content: [
        "Relative references shift when rows or columns are inserted or deleted, and when a formula is copied to another cell. Absolute references, written with ",
        { code: "$" },
        ", do not. This is the behaviour a spreadsheet user expects, and it is applied to the stored formula text, so the change is visible in the file afterwards.",
      ],
    },
    { kind: "heading", id: "measured", text: "Measured" },
    {
      kind: "table",
      caption:
        "Release build, on a 1.6 MB four-sheet workbook with 20,739 cells and 4,530 formulas",
      head: ["Operation", "Time"],
      rows: [
        ["Open", "0.09 s"],
        ["Save", "0.11 s"],
        ["Recalculate everything", "0.41 s"],
      ],
    },
    {
      kind: "paragraph",
      content: [
        "All 4,530 formulas in that workbook produced the same results as the values the file had already cached.",
      ],
    },
    { kind: "heading", id: "limits", text: "Prerequisites and limits" },
    {
      kind: "list",
      items: [
        [
          "Array formulas, ",
          { code: "INDIRECT" },
          ", ",
          { code: "OFFSET" },
          " and defined names are not evaluated. Defined names survive a save.",
        ],
        [
          "A formula the engine does not evaluate keeps its cached value from the file, which will not update as its inputs change.",
        ],
        ["Recalculation happens in the macOS app. The browser viewer on this site does not recalculate."],
      ],
    },
    {
      kind: "paragraph",
      content: [
        "To check a specific workbook against the engine, run the opt-in test described in ",
        { text: "the article on formula coverage", href: "/blog/will-my-formulas-work/" },
        ".",
      ],
    },
  ],
};
