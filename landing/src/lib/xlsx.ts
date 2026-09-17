import { ZipArchive, ZipError } from "./zip";

/** A parsed workbook, as much of one as a read-only viewer needs. */
export interface ParsedWorkbook {
  fileName: string;
  fileSize: number;
  sheets: ParsedSheet[];
  /** Parts present in the package that this viewer does not render. */
  carriedParts: string[];
}

export interface ParsedSheet {
  name: string;
  columnCount: number;
  rowCount: number;
  /** Dense grid of the used range, row-major, 1-based addresses flattened. */
  rows: ParsedCell[][];
  truncated: boolean;
}

export interface ParsedCell {
  /** Display text, already formatted for dates. */
  text: string;
  /** True when the underlying value is numeric, for alignment. */
  numeric: boolean;
  formula?: string;
}

export class XlsxError extends Error {}

/** Rows kept per sheet. A viewer in a tab is not a place to hold a million rows. */
export const MAX_ROWS = 2000;
export const MAX_COLUMNS = 256;

const RELS_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";

export async function readWorkbook(file: File): Promise<ParsedWorkbook> {
  let archive: ZipArchive;
  try {
    archive = ZipArchive.open(await file.arrayBuffer());
  } catch (error) {
    if (error instanceof ZipError) throw new XlsxError(error.message);
    throw new XlsxError("This file could not be read as an .xlsx workbook.");
  }

  if (!archive.has("xl/workbook.xml")) {
    throw new XlsxError(
      "This ZIP archive has no xl/workbook.xml part, so it is not an .xlsx workbook.",
    );
  }

  const workbookXml = parseXml(await archive.text("xl/workbook.xml"));
  const relationships = archive.has("xl/_rels/workbook.xml.rels")
    ? parseRelationships(parseXml(await archive.text("xl/_rels/workbook.xml.rels")))
    : new Map<string, string>();

  const sharedStrings = archive.has("xl/sharedStrings.xml")
    ? parseSharedStrings(parseXml(await archive.text("xl/sharedStrings.xml")))
    : [];

  const dateStyles = archive.has("xl/styles.xml")
    ? parseDateStyles(parseXml(await archive.text("xl/styles.xml")))
    : new Set<number>();

  const sheets: ParsedSheet[] = [];
  for (const element of Array.from(workbookXml.getElementsByTagName("sheet"))) {
    const name = element.getAttribute("name") ?? `Sheet ${sheets.length + 1}`;
    const relationshipId =
      element.getAttributeNS(RELS_NS, "id") ?? element.getAttribute("r:id") ?? "";
    const target = relationships.get(relationshipId);
    const path = target
      ? resolvePart(target)
      : `xl/worksheets/sheet${sheets.length + 1}.xml`;
    if (!archive.has(path)) continue;
    sheets.push(parseSheet(name, parseXml(await archive.text(path)), sharedStrings, dateStyles));
  }

  if (sheets.length === 0) {
    throw new XlsxError("This workbook declares no worksheets that could be read.");
  }

  return {
    fileName: file.name,
    fileSize: file.size,
    sheets,
    carriedParts: describeCarriedParts(archive.names()),
  };
}

/** Parts the viewer knowingly leaves undrawn, reported rather than hidden. */
function describeCarriedParts(names: string[]): string[] {
  const kinds: { label: string; match: (name: string) => boolean }[] = [
    { label: "charts", match: (name) => name.startsWith("xl/charts/") },
    { label: "drawings", match: (name) => name.startsWith("xl/drawings/") },
    { label: "images", match: (name) => name.startsWith("xl/media/") },
    { label: "pivot caches", match: (name) => name.startsWith("xl/pivotCache/") },
    { label: "pivot tables", match: (name) => name.startsWith("xl/pivotTables/") },
    { label: "tables", match: (name) => name.startsWith("xl/tables/") },
    { label: "a theme", match: (name) => name.startsWith("xl/theme/") },
  ];
  return kinds.filter((kind) => names.some(kind.match)).map((kind) => kind.label);
}

function parseXml(text: string): Document {
  const document = new DOMParser().parseFromString(text, "application/xml");
  if (document.getElementsByTagName("parsererror").length > 0) {
    throw new XlsxError("One of the XML parts inside this workbook is not valid XML.");
  }
  return document;
}

function parseRelationships(document: Document): Map<string, string> {
  const map = new Map<string, string>();
  for (const element of Array.from(document.getElementsByTagName("Relationship"))) {
    const id = element.getAttribute("Id");
    const target = element.getAttribute("Target");
    if (id && target) map.set(id, target);
  }
  return map;
}

/** Workbook relationship targets are relative to the xl/ directory. */
function resolvePart(target: string): string {
  if (target.startsWith("/")) return target.slice(1);
  if (target.startsWith("xl/")) return target;
  return `xl/${target.replace(/^\.\//, "")}`;
}

function parseSharedStrings(document: Document): string[] {
  return Array.from(document.getElementsByTagName("si")).map(textOf);
}

/** Concatenates the text runs of a string item, ignoring run formatting. */
function textOf(element: Element): string {
  return Array.from(element.getElementsByTagName("t"))
    .map((node) => node.textContent ?? "")
    .join("");
}

const BUILTIN_DATE_FORMATS = new Set([14, 15, 16, 17, 18, 19, 20, 21, 22, 45, 46, 47]);

/** Style indices whose number format renders a date or a time. */
function parseDateStyles(document: Document): Set<number> {
  const customDateFormats = new Set<number>();
  for (const element of Array.from(document.getElementsByTagName("numFmt"))) {
    const id = Number(element.getAttribute("numFmtId"));
    const code = element.getAttribute("formatCode") ?? "";
    const withoutLiterals = code.replace(/"[^"]*"/g, "").replace(/\\./g, "");
    if (/[dmyhs]/i.test(withoutLiterals) && !/^(general|@|0|#)/i.test(withoutLiterals)) {
      customDateFormats.add(id);
    }
  }

  const dateStyles = new Set<number>();
  const cellXfs = document.getElementsByTagName("cellXfs")[0];
  if (!cellXfs) return dateStyles;
  Array.from(cellXfs.getElementsByTagName("xf")).forEach((xf, index) => {
    const id = Number(xf.getAttribute("numFmtId") ?? "0");
    if (BUILTIN_DATE_FORMATS.has(id) || customDateFormats.has(id)) dateStyles.add(index);
  });
  return dateStyles;
}

function parseSheet(
  name: string,
  document: Document,
  sharedStrings: string[],
  dateStyles: Set<number>,
): ParsedSheet {
  const rowElements = Array.from(document.getElementsByTagName("row"));
  const rows: ParsedCell[][] = [];
  let columnCount = 0;
  let truncated = false;
  let lastRowIndex = 0;

  for (const rowElement of rowElements) {
    const rowIndex = Number(rowElement.getAttribute("r") ?? rows.length + 1);
    if (rowIndex > MAX_ROWS) {
      truncated = true;
      continue;
    }
    lastRowIndex = Math.max(lastRowIndex, rowIndex);
    const cells: ParsedCell[] = [];
    for (const cellElement of Array.from(rowElement.getElementsByTagName("c"))) {
      const address = cellElement.getAttribute("r") ?? "";
      const columnIndex = columnIndexOf(address, cells.length);
      if (columnIndex >= MAX_COLUMNS) {
        truncated = true;
        continue;
      }
      const cell = parseCell(cellElement, sharedStrings, dateStyles);
      if (!cell) continue;
      cells[columnIndex] = cell;
      columnCount = Math.max(columnCount, columnIndex + 1);
    }
    rows[rowIndex - 1] = cells;
  }

  const dense: ParsedCell[][] = [];
  for (let index = 0; index < lastRowIndex; index += 1) {
    dense.push(rows[index] ?? []);
  }

  return { name, rows: dense, columnCount, rowCount: dense.length, truncated };
}

const EMPTY_CELL: ParsedCell = { text: "", numeric: false };

function parseCell(
  element: Element,
  sharedStrings: string[],
  dateStyles: Set<number>,
): ParsedCell | null {
  const type = element.getAttribute("t") ?? "n";
  const styleIndex = Number(element.getAttribute("s") ?? "-1");
  const formulaElement = element.getElementsByTagName("f")[0];
  const formula = formulaElement?.textContent?.trim() || undefined;
  const valueElement = element.getElementsByTagName("v")[0];
  const raw = valueElement?.textContent ?? "";

  switch (type) {
    case "s": {
      const text = sharedStrings[Number(raw)] ?? "";
      return text || formula ? { text, numeric: false, formula } : null;
    }
    case "inlineStr": {
      const inline = element.getElementsByTagName("is")[0];
      const text = inline ? textOf(inline) : "";
      return text || formula ? { text, numeric: false, formula } : null;
    }
    case "str":
      return raw || formula ? { text: raw, numeric: false, formula } : null;
    case "b":
      if (!raw && !formula) return null;
      return { text: raw === "1" ? "TRUE" : "FALSE", numeric: false, formula };
    case "e":
      return { text: raw, numeric: false, formula };
    default: {
      if (!raw) return formula ? { ...EMPTY_CELL, formula } : null;
      const value = Number(raw);
      if (Number.isNaN(value)) return { text: raw, numeric: false, formula };
      if (dateStyles.has(styleIndex)) {
        return { text: serialToIsoDate(value), numeric: false, formula };
      }
      return { text: formatNumber(value), numeric: true, formula };
    }
  }
}

function formatNumber(value: number): string {
  if (Number.isInteger(value)) return String(value);
  return String(Number(value.toPrecision(12)));
}

/**
 * Excel's day 0 is 30 December 1899, and the serial 60 is a leap day that never
 * existed; serials at or below 60 are shifted so 1 becomes 1 January 1900.
 */
export function serialToIsoDate(serial: number): string {
  const wholeDays = Math.floor(serial);
  const fraction = serial - wholeDays;
  const epoch = wholeDays > 59 ? Date.UTC(1899, 11, 30) : Date.UTC(1899, 11, 31);
  const iso = new Date(epoch + wholeDays * 86400000).toISOString().slice(0, 10);
  if (fraction <= 0) return iso;
  const seconds = Math.round(fraction * 86400);
  const time = [
    Math.floor(seconds / 3600),
    Math.floor((seconds % 3600) / 60),
    seconds % 60,
  ]
    .map((part) => String(part).padStart(2, "0"))
    .join(":");
  return wholeDays === 0 ? time : `${iso} ${time}`;
}

/** Turns "BC12" into a zero-based column index, falling back to position. */
export function columnIndexOf(address: string, fallback: number): number {
  const letters = /^([A-Z]+)/.exec(address.toUpperCase())?.[1];
  if (!letters) return fallback;
  let index = 0;
  for (const character of letters) {
    index = index * 26 + (character.charCodeAt(0) - 64);
  }
  return index - 1;
}

/** Zero-based column index to its spreadsheet letters. */
export function columnName(index: number): string {
  let name = "";
  let remaining = index + 1;
  while (remaining > 0) {
    const remainder = (remaining - 1) % 26;
    name = String.fromCharCode(65 + remainder) + name;
    remaining = Math.floor((remaining - remainder) / 26);
  }
  return name;
}

/** RFC 4180 CSV for the sheet currently on screen. */
export function sheetToCsv(sheet: ParsedSheet): string {
  return sheet.rows
    .map((row) => {
      const cells: string[] = [];
      for (let index = 0; index < sheet.columnCount; index += 1) {
        const text = row[index]?.text ?? "";
        cells.push(/[",\n\r]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text);
      }
      return cells.join(",");
    })
    .join("\r\n");
}
