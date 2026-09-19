import XCTest
@testable import XLSXKit

final class EditingTests: XCTestCase {
    private func makeWorkbook() -> Workbook {
        var workbook = Workbook()
        try? workbook.renameSheet(at: 0, to: "Data")
        try? workbook.insertSheet(named: "Report", at: 1)
        for row in 1...5 {
            workbook.sheets[0][row, 1] = Cell(value: .text("row\(row)"))
            workbook.sheets[0][row, 2] = Cell(value: .number(Double(row * 10)))
        }
        return workbook
    }

    // MARK: - Typed input

    func testParsesNumbers() {
        XCTAssertEqual(CellInput.parse("42").value, .number(42))
        XCTAssertEqual(CellInput.parse("-3.5").value, .number(-3.5))
        XCTAssertEqual(CellInput.parse("1,234.5").value, .number(1234.5))
        XCTAssertEqual(CellInput.parse(" 7 ").value, .number(7))
    }

    func testParsesFormulas() {
        let parsed = CellInput.parse("=SUM(A1:A3)")
        XCTAssertEqual(parsed.formula, "SUM(A1:A3)")
        XCTAssertEqual(CellInput.parse("=").value, .text("="), "a lone equals sign is text")
    }

    func testParsesPercentAndKeepsItsFormat() {
        let parsed = CellInput.parse("40%")
        XCTAssertEqual(parsed.value, .number(0.4))
        XCTAssertEqual(parsed.numberFormat, "0%")
        XCTAssertEqual(CellInput.parse("12.50%").numberFormat, "0.00%")
    }

    func testParsesDates() {
        let parsed = CellInput.parse("2026-09-16")
        XCTAssertEqual(parsed.value, .number(46281))
        XCTAssertEqual(parsed.numberFormat, "yyyy-mm-dd")
        XCTAssertEqual(CellInput.parse("16 Sep 2026").value, .number(46281))
    }

    func testParsesBooleansAndText() {
        XCTAssertEqual(CellInput.parse("TRUE").value, .boolean(true))
        XCTAssertEqual(CellInput.parse("false").value, .boolean(false))
        XCTAssertEqual(CellInput.parse("hello").value, .text("hello"))
        XCTAssertEqual(CellInput.parse("'123").value, .text("123"), "an apostrophe forces text")
        XCTAssertEqual(CellInput.parse("").value, .empty)
    }

    func testEditingTextRoundTrips() {
        XCTAssertEqual(CellInput.editingText(for: Cell(formula: "A1+1"), numberFormat: "General"), "=A1+1")
        XCTAssertEqual(CellInput.editingText(for: Cell(value: .number(46281)), numberFormat: "yyyy-mm-dd"),
                       "2026-09-16")
        XCTAssertEqual(CellInput.editingText(for: Cell(value: .number(2.5)), numberFormat: "0.00"), "2.5")
        XCTAssertEqual(CellInput.editingText(for: Cell(value: .text("x")), numberFormat: "General"), "x")
    }

    // MARK: - Rows and columns

    func testInsertingRowsMovesCellsDown() {
        var workbook = makeWorkbook()
        workbook.insertRows(at: 2, count: 2, inSheet: 0)

        XCTAssertEqual(workbook.sheets[0][1, 1].value, .text("row1"))
        XCTAssertEqual(workbook.sheets[0][2, 1].value, .empty)
        XCTAssertEqual(workbook.sheets[0][3, 1].value, .empty)
        XCTAssertEqual(workbook.sheets[0][4, 1].value, .text("row2"))
        XCTAssertEqual(workbook.sheets[0][7, 1].value, .text("row5"))
    }

    func testDeletingRowsMovesCellsUp() {
        var workbook = makeWorkbook()
        workbook.removeRows(at: 2, count: 2, inSheet: 0)

        XCTAssertEqual(workbook.sheets[0][1, 1].value, .text("row1"))
        XCTAssertEqual(workbook.sheets[0][2, 1].value, .text("row4"))
        XCTAssertEqual(workbook.sheets[0][3, 1].value, .text("row5"))
        XCTAssertEqual(workbook.sheets[0].usedExtent.rows, 3)
    }

    func testInsertingColumnsMovesCellsAndWidths() {
        var workbook = makeWorkbook()
        workbook.sheets[0].setWidth(30, forColumn: 2)
        workbook.insertColumns(at: 1, count: 1, inSheet: 0)

        XCTAssertEqual(workbook.sheets[0][1, 1].value, .empty)
        XCTAssertEqual(workbook.sheets[0][1, 2].value, .text("row1"))
        XCTAssertEqual(workbook.sheets[0][1, 3].value, .number(10))
        XCTAssertEqual(workbook.sheets[0].width(ofColumn: 3), 30, "the width follows its column")
    }

    func testDeletingColumnsRemovesTheirCells() {
        var workbook = makeWorkbook()
        workbook.removeColumns(at: 1, count: 1, inSheet: 0)
        XCTAssertEqual(workbook.sheets[0][1, 1].value, .number(10))
        XCTAssertEqual(workbook.sheets[0][1, 2].value, .empty)
    }

    func testMergesFollowInsertedRows() {
        var workbook = makeWorkbook()
        workbook.sheets[0].merges = [CellRange(a1: "A3:C3")!]
        workbook.insertRows(at: 1, count: 1, inSheet: 0)
        XCTAssertEqual(workbook.sheets[0].merges.map(\.a1), ["A4:C4"])
    }

    // MARK: - Formula adjustment

    func testInsertedRowsMoveFormulaReferences() {
        var workbook = makeWorkbook()
        workbook.sheets[0][6, 2] = Cell(formula: "SUM(B1:B5)")
        workbook.insertRows(at: 1, count: 1, inSheet: 0)
        XCTAssertEqual(workbook.sheets[0][7, 2].formula, "SUM(B2:B6)")
    }

    func testDeletedRowsBreakReferencesIntoThem() {
        var workbook = makeWorkbook()
        workbook.sheets[0][6, 2] = Cell(formula: "B3+B4")
        workbook.removeRows(at: 3, count: 1, inSheet: 0)
        XCTAssertEqual(workbook.sheets[0][5, 2].formula, "#REF!+B3")
    }

    func testCrossSheetReferencesAdjustToo() {
        var workbook = makeWorkbook()
        workbook.sheets[1][1, 1] = Cell(formula: "Data!B5*2")
        workbook.insertRows(at: 1, count: 1, inSheet: 0)
        XCTAssertEqual(workbook.sheets[1][1, 1].formula, "Data!B6*2")
    }

    /// Editing one sheet must not disturb formulas pointing at another.
    func testReferencesToOtherSheetsAreLeftAlone() {
        var workbook = makeWorkbook()
        workbook.sheets[0][6, 1] = Cell(formula: "Report!A5+B5")
        workbook.insertRows(at: 1, count: 1, inSheet: 0)
        XCTAssertEqual(workbook.sheets[0][7, 1].formula, "Report!A5+B6",
                       "only the reference into the edited sheet moves")
    }

    func testQuotedSheetNamesAreMatched() {
        var workbook = makeWorkbook()
        try? workbook.renameSheet(at: 0, to: "Raw Data")
        workbook.sheets[1][1, 1] = Cell(formula: "'Raw Data'!B5")
        workbook.insertRows(at: 1, count: 1, inSheet: 0)
        XCTAssertEqual(workbook.sheets[1][1, 1].formula, "'Raw Data'!B6")
    }

    func testStructuralEditsSurviveASaveAndReload() throws {
        var workbook = makeWorkbook()
        workbook.sheets[0][6, 2] = Cell(formula: "SUM(B1:B5)")
        workbook.insertRows(at: 1, count: 1, inSheet: 0)
        Recalculator.recalculate(&workbook)

        let reloaded = try XLSXReader.read(data: XLSXWriter.data(for: workbook))
        XCTAssertEqual(reloaded.sheets[0][7, 2].formula, "SUM(B2:B6)")
        XCTAssertEqual(reloaded.sheets[0][7, 2].value, .number(150))
    }

    // MARK: - Sheets

    func testSheetNameRules() {
        XCTAssertTrue(Workbook.isValidSheetName("Sales 2026"))
        XCTAssertFalse(Workbook.isValidSheetName(""))
        XCTAssertFalse(Workbook.isValidSheetName("   "))
        XCTAssertFalse(Workbook.isValidSheetName("a/b"))
        XCTAssertFalse(Workbook.isValidSheetName("[data]"))
        XCTAssertFalse(Workbook.isValidSheetName(String(repeating: "x", count: 32)))
        XCTAssertTrue(Workbook.isValidSheetName(String(repeating: "x", count: 31)))
    }

    func testSheetOperations() throws {
        var workbook = makeWorkbook()
        XCTAssertThrowsError(try workbook.insertSheet(named: "Data", at: 0), "duplicate names are refused")
        XCTAssertThrowsError(try workbook.renameSheet(at: 1, to: "Data"))

        try workbook.insertSheet(named: "Third", at: 2)
        XCTAssertEqual(workbook.sheets.map(\.name), ["Data", "Report", "Third"])

        workbook.moveSheet(from: 2, to: 0)
        XCTAssertEqual(workbook.sheets.map(\.name), ["Third", "Data", "Report"])

        try workbook.removeSheet(at: 0)
        XCTAssertEqual(workbook.sheets.map(\.name), ["Data", "Report"])
    }

    func testTheLastSheetCannotBeDeleted() throws {
        var workbook = Workbook()
        XCTAssertThrowsError(try workbook.removeSheet(at: 0))
    }

    func testDuplicateSheetGetsAUniqueName() throws {
        var workbook = makeWorkbook()
        try workbook.duplicateSheet(at: 0)
        try workbook.duplicateSheet(at: 0)
        XCTAssertEqual(workbook.sheets.map(\.name), ["Data", "Data copy2", "Data copy", "Report"])
        XCTAssertEqual(Set(workbook.sheets.map(\.partName)).count, 4, "parts must not collide")
    }

    // MARK: - Styles

    func testApplyingStylesReusesEquivalentEntries() {
        var styles = WorkbookStyles()
        let bold = styles.applying(.bold(true), to: 0)
        let boldAgain = styles.applying(.bold(true), to: 0)
        XCTAssertEqual(bold, boldAgain, "an equivalent format should not add a second entry")

        let boldItalic = styles.applying(.italic(true), to: bold)
        XCTAssertNotEqual(boldItalic, bold)
        XCTAssertTrue(styles.font(forStyle: boldItalic).bold)
        XCTAssertTrue(styles.font(forStyle: boldItalic).italic)

        let plain = styles.applying(.bold(false), to: bold)
        XCTAssertEqual(plain, 0, "removing the only difference returns the original style")
    }

    func testBackgroundAndAlignment() {
        var styles = WorkbookStyles()
        let filled = styles.applying(.backgroundColor("FFFF0000"), to: 0)
        XCTAssertEqual(styles.fill(forStyle: filled).solidRGB, "FFFF0000")

        let centred = styles.applying(.horizontalAlignment(.center), to: filled)
        XCTAssertEqual(styles.alignment(forStyle: centred).horizontal, .center)
        XCTAssertEqual(styles.fill(forStyle: centred).solidRGB, "FFFF0000", "other attributes carry over")
    }
}
