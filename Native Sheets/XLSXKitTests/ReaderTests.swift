import XCTest
@testable import XLSXKit

final class ReaderTests: XCTestCase {
    func testReadsSheetsInOrder() throws {
        let workbook = try XLSXReader.read(data: Fixtures.sampleWorkbook())
        XCTAssertEqual(workbook.sheets.map(\.name), ["Summary", "Data", "Notes"])
    }

    func testReadsValuesAndTypes() throws {
        let workbook = try XLSXReader.read(data: Fixtures.sampleWorkbook())
        let sheet = workbook.sheets[1]
        XCTAssertEqual(sheet[1, 1].value, .text("Region"))
        XCTAssertEqual(sheet[2, 2].value, .number(1200))
        XCTAssertEqual(sheet[2, 3].value, .boolean(true))
        XCTAssertEqual(sheet[3, 3].value, .error("#DIV/0!"))
    }

    func testReadsSharedStrings() throws {
        let workbook = try XLSXReader.read(data: Fixtures.sampleWorkbook())
        XCTAssertEqual(workbook.sheets[0][1, 1].value, .text("Quarterly report"))
    }

    func testReadsInlineStrings() throws {
        let workbook = try XLSXReader.read(data: Fixtures.sampleWorkbook())
        XCTAssertEqual(workbook.sheets[2][1, 1].value, .text("Inline note"))
    }

    func testReadsFormulasAndCachedValues() throws {
        let workbook = try XLSXReader.read(data: Fixtures.sampleWorkbook())
        let cell = workbook.sheets[1][4, 2]
        XCTAssertEqual(cell.formula, "SUM(B2:B3)")
        XCTAssertEqual(cell.value, .number(3100))
    }

    func testExpandsSharedFormulas() throws {
        let workbook = try XLSXReader.read(data: Fixtures.sampleWorkbook())
        let sheet = workbook.sheets[1]
        XCTAssertEqual(sheet[2, 4].formula, "B2*2")
        XCTAssertEqual(sheet[3, 4].formula, "B3*2", "follower of a shared formula should be translated")
    }

    func testReadsLayout() throws {
        let workbook = try XLSXReader.read(data: Fixtures.sampleWorkbook())
        let sheet = workbook.sheets[1]
        XCTAssertEqual(sheet.width(ofColumn: 1), 24)
        XCTAssertEqual(sheet.height(ofRow: 1), 30)
        XCTAssertEqual(sheet.freeze, FreezePane(columns: 1, rows: 1))
        XCTAssertFalse(sheet.showGridLines)
        XCTAssertEqual(sheet.merges.map(\.a1), ["A6:C6"])
    }

    func testReadsStyles() throws {
        let workbook = try XLSXReader.read(data: Fixtures.sampleWorkbook())
        let sheet = workbook.sheets[1]
        let header = workbook.styles.font(forStyle: sheet[1, 1].styleIndex)
        XCTAssertTrue(header.bold)
        XCTAssertEqual(workbook.styles.numberFormatCode(forStyle: sheet[2, 2].styleIndex), "#,##0.00")
    }

    func testPreservesUnmodelledParts() throws {
        let workbook = try XLSXReader.read(data: Fixtures.sampleWorkbook())
        XCTAssertNotNil(workbook.package["xl/theme/theme1.xml"])
        XCTAssertNotNil(workbook.sheets[1].preserved["autoFilter"])
    }

    func testRejectsAWorkbookWithoutSheets() {
        let archive = ZipWriter.archive([
            ZipWriter.Entry(name: "xl/workbook.xml", data: Data("<workbook><sheets/></workbook>".utf8))
        ])
        XCTAssertThrowsError(try XLSXReader.read(data: archive))
    }

    /// The editor must cope with either prefix convention, since the sample
    /// workbook prefixes every element and Excel does not.
    func testReadsPrefixedAndUnprefixedMarkup() throws {
        let prefixed = try XLSXReader.read(data: Fixtures.sampleWorkbook(prefixed: true))
        let plain = try XLSXReader.read(data: Fixtures.sampleWorkbook(prefixed: false))
        XCTAssertEqual(prefixed.sheets.map(\.name), plain.sheets.map(\.name))
        XCTAssertEqual(prefixed.sheets[1][2, 2].value, plain.sheets[1][2, 2].value)
        XCTAssertEqual(prefixed.sheets[1].freeze, plain.sheets[1].freeze)
    }
}
