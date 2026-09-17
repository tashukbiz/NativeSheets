import { strict as assert } from "node:assert";
import test from "node:test";
import { execFileSync } from "node:child_process";
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { JSDOM } from "jsdom";
import {
  MAX_ROWS,
  XlsxError,
  columnIndexOf,
  columnName,
  readWorkbook,
  serialToIsoDate,
  sheetToCsv,
} from "../src/lib/xlsx";

/**
 * The parser runs in a browser, so the test gives it the browser globals it
 * uses and a workbook built by the system `zip`, not by the code under test.
 */
const dom = new JSDOM("<!doctype html>");
globalThis.DOMParser = dom.window.DOMParser;

const parts: Record<string, string> = {
  "[Content_Types].xml": `<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml"/></Types>`,
  "xl/_rels/workbook.xml.rels": `<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Target="worksheets/sheet1.xml" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet"/><Relationship Id="rId2" Target="worksheets/sheet2.xml" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet"/></Relationships>`,
  "xl/workbook.xml": `<?xml version="1.0"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Totals" sheetId="1" r:id="rId1"/><sheet name="Notes" sheetId="2" r:id="rId2"/></sheets></workbook>`,
  "xl/sharedStrings.xml": `<?xml version="1.0"?><sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="3" uniqueCount="3"><si><t>Region</t></si><si><t>North, west</t></si><si><r><t>Split </t></r><r><t>run</t></r></si></sst>`,
  "xl/styles.xml": `<?xml version="1.0"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><numFmts count="1"><numFmt numFmtId="164" formatCode="yyyy\\-mm\\-dd"/></numFmts><cellXfs count="3"><xf numFmtId="0"/><xf numFmtId="164"/><xf numFmtId="14"/></cellXfs></styleSheet>`,
  "xl/worksheets/sheet1.xml": `<?xml version="1.0"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="inlineStr"><is><t>Units</t></is></c><c r="C1" t="s"><v>2</v></c></row><row r="2"><c r="A2" t="s"><v>1</v></c><c r="B2"><v>120</v></c><c r="C2"><f>B2*2</f><v>240</v></c></row><row r="3"><c r="A3" s="1"><v>46000</v></c><c r="B3" t="b"><v>1</v></c><c r="C3" t="e"><v>#DIV/0!</v></c></row><row r="4"><c r="D4" s="2"><v>1</v></c><c r="E4"><v>3.5</v></c></row></sheetData></worksheet>`,
  "xl/worksheets/sheet2.xml": `<?xml version="1.0"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData/></worksheet>`,
  "xl/charts/chart1.xml": `<?xml version="1.0"?><chart/>`,
};

function buildWorkbook(): Buffer {
  const directory = mkdtempSync(join(tmpdir(), "xlsx-test-"));
  for (const [name, content] of Object.entries(parts)) {
    const path = join(directory, name);
    mkdirSync(join(path, ".."), { recursive: true });
    writeFileSync(path, content);
  }
  const archive = join(directory, "book.xlsx");
  execFileSync("zip", ["-q", "-r", archive, ...Object.keys(parts)], { cwd: directory });
  return readFileSync(archive);
}

/** A File the parser can read, backed by the bytes the system zip produced. */
function fileFrom(bytes: Buffer, name = "book.xlsx"): File {
  return new File([new Uint8Array(bytes)], name, {
    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  });
}

const workbookBytes = buildWorkbook();

test("reads sheet names in workbook order", async () => {
  const workbook = await readWorkbook(fileFrom(workbookBytes));
  assert.deepEqual(
    workbook.sheets.map((sheet) => sheet.name),
    ["Totals", "Notes"],
  );
  assert.equal(workbook.fileName, "book.xlsx");
});

test("reads shared, inline, numeric, boolean and error cells", async () => {
  const [sheet] = (await readWorkbook(fileFrom(workbookBytes))).sheets;
  assert.equal(sheet.rows[0][0].text, "Region");
  assert.equal(sheet.rows[0][1].text, "Units");
  assert.equal(sheet.rows[0][2].text, "Split run");
  assert.equal(sheet.rows[1][0].text, "North, west");
  assert.equal(sheet.rows[1][1].text, "120");
  assert.equal(sheet.rows[1][1].numeric, true);
  assert.equal(sheet.rows[2][1].text, "TRUE");
  assert.equal(sheet.rows[2][2].text, "#DIV/0!");
});

test("keeps the formula and the value cached with it", async () => {
  const [sheet] = (await readWorkbook(fileFrom(workbookBytes))).sheets;
  assert.equal(sheet.rows[1][2].formula, "B2*2");
  assert.equal(sheet.rows[1][2].text, "240");
});

test("applies custom and built-in date formats", async () => {
  const [sheet] = (await readWorkbook(fileFrom(workbookBytes))).sheets;
  assert.equal(sheet.rows[2][0].text, "2025-12-09");
  assert.equal(sheet.rows[3][3].text, "1900-01-01");
});

test("respects sparse addresses rather than cell order", async () => {
  const [sheet] = (await readWorkbook(fileFrom(workbookBytes))).sheets;
  assert.equal(sheet.columnCount, 5);
  assert.equal(sheet.rows[3][3].text, "1900-01-01");
  assert.equal(sheet.rows[3][4].text, "3.5");
});

test("reports parts it carries but does not draw", async () => {
  const workbook = await readWorkbook(fileFrom(workbookBytes));
  assert.deepEqual(workbook.carriedParts, ["charts"]);
});

test("an empty sheet is read as empty, not as an error", async () => {
  const workbook = await readWorkbook(fileFrom(workbookBytes));
  assert.equal(workbook.sheets[1].rowCount, 0);
});

test("CSV quotes separators, quotes and keeps the visible range", async () => {
  const [sheet] = (await readWorkbook(fileFrom(workbookBytes))).sheets;
  const csv = sheetToCsv(sheet);
  const [header, second] = csv.split("\r\n");
  assert.equal(header, "Region,Units,Split run,,");
  assert.equal(second, '"North, west",120,240,,');
});

test("a file that is not a ZIP archive fails with a readable message", async () => {
  await assert.rejects(
    () => readWorkbook(fileFrom(Buffer.from("this is a csv,not a workbook"), "notes.csv")),
    (error: unknown) => error instanceof XlsxError && /not a ZIP archive/.test((error as Error).message),
  );
});

test("a ZIP archive that is not a workbook fails with a readable message", async () => {
  const directory = mkdtempSync(join(tmpdir(), "zip-test-"));
  writeFileSync(join(directory, "hello.txt"), "hello");
  execFileSync("zip", ["-q", "plain.zip", "hello.txt"], { cwd: directory });
  await assert.rejects(
    () => readWorkbook(fileFrom(readFileSync(join(directory, "plain.zip")), "plain.zip")),
    (error: unknown) => error instanceof XlsxError && /workbook\.xml/.test((error as Error).message),
  );
});

test("column names and indices round-trip", () => {
  for (const [index, name] of [
    [0, "A"],
    [25, "Z"],
    [26, "AA"],
    [27, "AB"],
    [701, "ZZ"],
    [702, "AAA"],
  ] as const) {
    assert.equal(columnName(index), name);
    assert.equal(columnIndexOf(`${name}7`, -1), index);
  }
  assert.equal(columnIndexOf("", 4), 4);
});

test("serial dates use the 1900 system, including its leap-day quirk", () => {
  assert.equal(serialToIsoDate(1), "1900-01-01");
  assert.equal(serialToIsoDate(59), "1900-02-28");
  assert.equal(serialToIsoDate(61), "1900-03-01");
  assert.equal(serialToIsoDate(45000), "2023-03-15");
  assert.equal(serialToIsoDate(45000.5), "2023-03-15 12:00:00");
});

test("the row cap is a bounded number, not an unbounded read", () => {
  assert.ok(MAX_ROWS > 0 && MAX_ROWS <= 10000);
});
