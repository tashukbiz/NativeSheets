import XCTest
@testable import XLSXKit

final class WriterTests: XCTestCase {
    private func roundTrip(_ workbook: Workbook) throws -> Workbook {
        try XLSXReader.read(data: XLSXWriter.data(for: workbook))
    }

    func testRoundTripsValues() throws {
        let original = try XLSXReader.read(data: Fixtures.sampleWorkbook())
        let reloaded = try roundTrip(original)

        XCTAssertEqual(reloaded.sheets.map(\.name), original.sheets.map(\.name))
        for (index, sheet) in original.sheets.enumerated() {
            for (rowIndex, row) in sheet.rows {
                for (column, cell) in row.cells {
                    let address = CellAddress(row: rowIndex, column: column)
                    XCTAssertEqual(reloaded.sheets[index][address].value, cell.value,
                                   "\(sheet.name)!\(address.a1)")
                    XCTAssertEqual(reloaded.sheets[index][address].formula, cell.formula,
                                   "\(sheet.name)!\(address.a1)")
                    XCTAssertEqual(reloaded.sheets[index][address].styleIndex, cell.styleIndex,
                                   "\(sheet.name)!\(address.a1)")
                }
            }
        }
    }

    func testRoundTripsLayout() throws {
        let original = try XLSXReader.read(data: Fixtures.sampleWorkbook())
        let reloaded = try roundTrip(original)
        let sheet = reloaded.sheets[1]

        XCTAssertEqual(sheet.width(ofColumn: 1), 24)
        XCTAssertEqual(sheet.width(ofColumn: 3), 14)
        XCTAssertEqual(sheet.height(ofRow: 1), 30)
        XCTAssertEqual(sheet.freeze, FreezePane(columns: 1, rows: 1))
        XCTAssertFalse(sheet.showGridLines)
        XCTAssertEqual(sheet.tabColor, "FF4472C4")
        XCTAssertEqual(sheet.merges.map(\.a1), ["A6:C6"])
        XCTAssertEqual(reloaded.activeSheetIndex, 1)
    }

    func testKeepsPartsItDoesNotUnderstand() throws {
        let original = try XLSXReader.read(data: Fixtures.sampleWorkbook())
        let data = try XLSXWriter.data(for: original)
        let archive = try ZipArchive(data: data)

        XCTAssertEqual(try archive.data(for: "xl/theme/theme1.xml"), Data("<theme/>".utf8))

        let sheet = String(decoding: try archive.data(for: "xl/worksheets/sheet2.xml"), as: UTF8.self)
        XCTAssertTrue(sheet.contains("autoFilter"), "auto filter should survive a save")
        XCTAssertTrue(sheet.contains("pageMargins"), "page setup should survive a save")
        XCTAssertTrue(sheet.contains("zoomScale"), "unmodelled view attributes should survive a save")

        let workbookPart = String(decoding: try archive.data(for: "xl/workbook.xml"), as: UTF8.self)
        XCTAssertTrue(workbookPart.contains("definedName"), "defined names should survive a save")
    }

    func testWritesSectionsInSchemaOrder() throws {
        let original = try XLSXReader.read(data: Fixtures.sampleWorkbook())
        let archive = try ZipArchive(data: try XLSXWriter.data(for: original))
        let sheet = String(decoding: try archive.data(for: "xl/worksheets/sheet2.xml"), as: UTF8.self)

        let order = ["sheetPr", "dimension", "sheetViews", "cols", "sheetData",
                     "autoFilter", "mergeCells", "pageMargins"]
        var lastPosition = sheet.startIndex
        for section in order {
            guard let position = sheet.range(of: "<" + section) else {
                XCTFail("missing section \(section)")
                continue
            }
            XCTAssertGreaterThan(position.lowerBound, lastPosition, "\(section) is out of schema order")
            lastPosition = position.lowerBound
        }
    }

    func testBuildsASharedStringTable() throws {
        var workbook = Workbook()
        workbook.sheets[0][1, 1] = Cell(value: .text("Repeat"))
        workbook.sheets[0][2, 1] = Cell(value: .text("Repeat"))
        workbook.sheets[0][3, 1] = Cell(value: .text("Other"))

        let archive = try ZipArchive(data: try XLSXWriter.data(for: workbook))
        let strings = String(decoding: try archive.data(for: "xl/sharedStrings.xml"), as: UTF8.self)
        XCTAssertTrue(strings.contains("uniqueCount=\"2\""))
        XCTAssertTrue(strings.contains("count=\"3\""))

        let reloaded = try roundTrip(workbook)
        XCTAssertEqual(reloaded.sheets[0][2, 1].value, .text("Repeat"))
    }

    func testWritesANewWorkbookExcelCanOpen() throws {
        var workbook = Workbook()
        workbook.sheets[0][1, 1] = Cell(value: .text("Hello"))
        workbook.sheets[0][1, 2] = Cell(value: .number(42))
        let reloaded = try roundTrip(workbook)

        XCTAssertEqual(reloaded.sheets.count, 1)
        XCTAssertEqual(reloaded.sheets[0][1, 1].value, .text("Hello"))
        XCTAssertEqual(reloaded.sheets[0][1, 2].value, .number(42))
    }

    func testAddedSheetGetsItsOwnPart() throws {
        var workbook = try XLSXReader.read(data: Fixtures.sampleWorkbook())
        try workbook.insertSheet(named: "Extra", at: 3)
        workbook.sheets[3][1, 1] = Cell(value: .text("New page"))

        let reloaded = try roundTrip(workbook)
        XCTAssertEqual(reloaded.sheets.map(\.name), ["Summary", "Data", "Notes", "Extra"])
        XCTAssertEqual(reloaded.sheets[3][1, 1].value, .text("New page"))
        XCTAssertEqual(reloaded.sheets[1][2, 2].value, .number(1200), "existing sheets should be untouched")
    }

    func testDeletedSheetDropsItsPart() throws {
        var workbook = try XLSXReader.read(data: Fixtures.sampleWorkbook())
        let removedPart = workbook.sheets[1].partName
        try workbook.removeSheet(at: 1)

        let data = try XLSXWriter.data(for: workbook)
        let archive = try ZipArchive(data: data)
        XCTAssertFalse(archive.contains(removedPart), "the deleted sheet's part should be gone")

        let types = String(decoding: try archive.data(for: "[Content_Types].xml"), as: UTF8.self)
        XCTAssertFalse(types.contains(removedPart), "the deleted sheet should leave no content type override")
        XCTAssertEqual(try XLSXReader.read(data: data).sheets.map(\.name), ["Summary", "Notes"])
    }

    func testDuplicatedSheetCarriesItsContent() throws {
        var workbook = try XLSXReader.read(data: Fixtures.sampleWorkbook())
        try workbook.duplicateSheet(at: 1)

        let reloaded = try roundTrip(workbook)
        XCTAssertEqual(reloaded.sheets.map(\.name), ["Summary", "Data", "Data copy", "Notes"])
        XCTAssertEqual(reloaded.sheets[2][2, 2].value, .number(1200))
        XCTAssertEqual(reloaded.sheets[2].freeze, FreezePane(columns: 1, rows: 1))
    }

    func testRegeneratesStylesOnlyWhenChanged() throws {
        let workbook = try XLSXReader.read(data: Fixtures.sampleWorkbook())
        let untouched = try ZipArchive(data: try XLSXWriter.data(for: workbook)).data(for: "xl/styles.xml")
        XCTAssertEqual(untouched, workbook.package["xl/styles.xml"], "styles should be copied when unchanged")

        var edited = workbook
        let styleIndex = edited.styles.applying(.bold(true), to: 0)
        edited.sheets[0][1, 1].styleIndex = styleIndex

        let reloaded = try roundTrip(edited)
        XCTAssertTrue(reloaded.styles.font(forStyle: reloaded.sheets[0][1, 1].styleIndex).bold)
        XCTAssertEqual(reloaded.styles.numberFormatCode(forStyle: 2), "#,##0.00", "existing styles should survive")

        let regenerated = String(
            decoding: try ZipArchive(data: try XLSXWriter.data(for: edited)).data(for: "xl/styles.xml"),
            as: UTF8.self
        )
        XCTAssertTrue(regenerated.contains("tableStyles"), "unmodelled style sections should survive")
        XCTAssertTrue(regenerated.contains("cellStyleXfs"))
    }

    func testAppliesANumberFormat() throws {
        var workbook = Workbook()
        let styleIndex = workbook.styles.applying(.numberFormat("0.0%"), to: 0)
        workbook.sheets[0][1, 1] = Cell(value: .number(0.25), styleIndex: styleIndex)

        let reloaded = try roundTrip(workbook)
        XCTAssertEqual(reloaded.styles.numberFormatCode(forStyle: reloaded.sheets[0][1, 1].styleIndex), "0.0%")
    }

    func testEscapesMarkupInCellText() throws {
        var workbook = Workbook()
        workbook.sheets[0][1, 1] = Cell(value: .text("<tag> & \"quoted\" 'text'"))
        workbook.sheets[0][2, 1] = Cell(value: .text("line1\nline2"))

        let reloaded = try roundTrip(workbook)
        XCTAssertEqual(reloaded.sheets[0][1, 1].value, .text("<tag> & \"quoted\" 'text'"))
        XCTAssertEqual(reloaded.sheets[0][2, 1].value, .text("line1\nline2"))
    }

    func testSheetNamesWithMarkupCharactersSurvive() throws {
        var workbook = Workbook()
        try workbook.renameSheet(at: 0, to: "R&D <2026>")
        XCTAssertEqual(try roundTrip(workbook).sheets[0].name, "R&D <2026>")
    }
}
