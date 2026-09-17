import XCTest
@testable import XLSXKit

final class FormulaTests: XCTestCase {
    /// A small workbook: Data!A1:C4 holds labels, numbers and a lookup table.
    private func makeWorkbook() -> Workbook {
        var workbook = Workbook()
        try? workbook.renameSheet(at: 0, to: "Data")
        try? workbook.insertSheet(named: "Other", at: 1)

        var sheet = workbook.sheets[0]
        sheet[1, 1] = Cell(value: .text("North"))
        sheet[2, 1] = Cell(value: .text("South"))
        sheet[3, 1] = Cell(value: .text("East"))
        sheet[4, 1] = Cell(value: .text("West"))
        sheet[1, 2] = Cell(value: .number(10))
        sheet[2, 2] = Cell(value: .number(20))
        sheet[3, 2] = Cell(value: .number(30))
        sheet[4, 2] = Cell(value: .number(40))
        sheet[1, 3] = Cell(value: .boolean(true))
        sheet[2, 3] = Cell(value: .text("text"))
        workbook.sheets[0] = sheet

        workbook.sheets[1][1, 1] = Cell(value: .number(100))
        return workbook
    }

    private func evaluate(_ formula: String, in workbook: Workbook? = nil,
                          at address: CellAddress = CellAddress(row: 10, column: 10)) -> CellValue {
        (workbook ?? makeWorkbook()).evaluate(formula, on: 0, at: address)
    }

    // MARK: - Parsing and operators

    func testArithmetic() {
        XCTAssertEqual(evaluate("=1+2*3"), .number(7))
        XCTAssertEqual(evaluate("=(1+2)*3"), .number(9))
        XCTAssertEqual(evaluate("=2^3^2"), .number(512), "exponent is right associative")
        XCTAssertEqual(evaluate("=-2^2"), .number(4))
        XCTAssertEqual(evaluate("=10/4"), .number(2.5))
        XCTAssertEqual(evaluate("=1/0"), .error("#DIV/0!"))
        XCTAssertEqual(evaluate("=50%"), .number(0.5))
        XCTAssertEqual(evaluate("=1.5e2"), .number(150))
    }

    func testComparisonAndConcatenation() {
        XCTAssertEqual(evaluate("=1<2"), .boolean(true))
        XCTAssertEqual(evaluate("=\"a\"=\"A\""), .boolean(true), "text compares case-insensitively")
        XCTAssertEqual(evaluate("=2<>2"), .boolean(false))
        XCTAssertEqual(evaluate("=\"ab\"&\"cd\""), .text("abcd"))
        XCTAssertEqual(evaluate("=\"n=\"&1"), .text("n=1"))
        XCTAssertEqual(evaluate("=\"say \"\"hi\"\"\""), .text("say \"hi\""))
    }

    func testReferences() {
        XCTAssertEqual(evaluate("=B1"), .number(10))
        XCTAssertEqual(evaluate("=$B$1+B2"), .number(30))
        XCTAssertEqual(evaluate("=A1"), .text("North"))
        XCTAssertEqual(evaluate("=Other!A1"), .number(100))
        XCTAssertEqual(evaluate("='Other'!A1"), .number(100))
        XCTAssertEqual(evaluate("=Missing!A1"), .error("#REF!"))
        XCTAssertEqual(evaluate("=Z99"), .number(0), "an empty cell reads as zero in arithmetic")
    }

    func testPositionFunctions() {
        XCTAssertEqual(evaluate("=ROW()", at: CellAddress(row: 7, column: 3)), .number(7))
        XCTAssertEqual(evaluate("=COLUMN()", at: CellAddress(row: 7, column: 3)), .number(3))
        XCTAssertEqual(evaluate("=ROWS(B1:B4)"), .number(4))
        XCTAssertEqual(evaluate("=COLUMNS(A1:C1)"), .number(3))
    }

    // MARK: - Functions

    func testAggregation() {
        XCTAssertEqual(evaluate("=SUM(B1:B4)"), .number(100))
        XCTAssertEqual(evaluate("=SUM(B1:B4,10)"), .number(110))
        XCTAssertEqual(evaluate("=AVERAGE(B1:B4)"), .number(25))
        XCTAssertEqual(evaluate("=MIN(B1:B4)"), .number(10))
        XCTAssertEqual(evaluate("=MAX(B1:B4)"), .number(40))
        XCTAssertEqual(evaluate("=MEDIAN(B1:B4)"), .number(25))
        XCTAssertEqual(evaluate("=COUNT(A1:C4)"), .number(4), "only numbers count")
        XCTAssertEqual(evaluate("=COUNTA(A1:C4)"), .number(10))
        XCTAssertEqual(evaluate("=COUNTBLANK(A1:C4)"), .number(2))
        XCTAssertEqual(evaluate("=PRODUCT(B1:B2)"), .number(200))
    }

    func testMathFunctions() {
        XCTAssertEqual(evaluate("=ROUND(2.345,2)"), .number(2.35))
        XCTAssertEqual(evaluate("=ROUNDUP(2.341,2)"), .number(2.35))
        XCTAssertEqual(evaluate("=ROUNDDOWN(2.349,2)"), .number(2.34))
        XCTAssertEqual(evaluate("=ROUND(1234.5,-2)"), .number(1200))
        XCTAssertEqual(evaluate("=ABS(-4)"), .number(4))
        XCTAssertEqual(evaluate("=INT(-2.5)"), .number(-3))
        XCTAssertEqual(evaluate("=MOD(-3,2)"), .number(1), "the result takes the divisor's sign")
        XCTAssertEqual(evaluate("=POWER(2,10)"), .number(1024))
        XCTAssertEqual(evaluate("=SQRT(16)"), .number(4))
        XCTAssertEqual(evaluate("=SQRT(-1)"), .error("#NUM!"))
        XCTAssertEqual(evaluate("=CEILING(7,5)"), .number(10))
        XCTAssertEqual(evaluate("=FLOOR(7,5)"), .number(5))
    }

    func testLogicalFunctions() {
        XCTAssertEqual(evaluate("=IF(B1>5,\"big\",\"small\")"), .text("big"))
        XCTAssertEqual(evaluate("=IF(B1>50,\"big\",\"small\")"), .text("small"))
        XCTAssertEqual(evaluate("=IF(FALSE,1)"), .boolean(false))
        XCTAssertEqual(evaluate("=AND(TRUE,1=1)"), .boolean(true))
        XCTAssertEqual(evaluate("=AND(TRUE,FALSE)"), .boolean(false))
        XCTAssertEqual(evaluate("=OR(FALSE,TRUE)"), .boolean(true))
        XCTAssertEqual(evaluate("=NOT(TRUE)"), .boolean(false))
        XCTAssertEqual(evaluate("=IFERROR(1/0,\"oops\")"), .text("oops"))
        XCTAssertEqual(evaluate("=IFERROR(5,\"oops\")"), .number(5))
        XCTAssertEqual(evaluate("=IFS(FALSE,1,TRUE,2)"), .number(2))
        XCTAssertEqual(evaluate("=SWITCH(2,1,\"a\",2,\"b\",\"other\")"), .text("b"))
        XCTAssertEqual(evaluate("=CHOOSE(2,\"a\",\"b\")"), .text("b"))
    }

    /// A lazy IF must not evaluate the branch it does not take.
    func testIfDoesNotEvaluateTheUntakenBranch() {
        XCTAssertEqual(evaluate("=IF(TRUE,\"safe\",1/0)"), .text("safe"))
    }

    func testTextFunctions() {
        XCTAssertEqual(evaluate("=LEN(\"hello\")"), .number(5))
        XCTAssertEqual(evaluate("=UPPER(\"abc\")"), .text("ABC"))
        XCTAssertEqual(evaluate("=LOWER(\"ABC\")"), .text("abc"))
        XCTAssertEqual(evaluate("=PROPER(\"hello world\")"), .text("Hello World"))
        XCTAssertEqual(evaluate("=TRIM(\"  a  b  \")"), .text("a b"))
        XCTAssertEqual(evaluate("=LEFT(\"abcdef\",3)"), .text("abc"))
        XCTAssertEqual(evaluate("=RIGHT(\"abcdef\",2)"), .text("ef"))
        XCTAssertEqual(evaluate("=MID(\"abcdef\",2,3)"), .text("bcd"))
        XCTAssertEqual(evaluate("=SUBSTITUTE(\"a-b-c\",\"-\",\"+\")"), .text("a+b+c"))
        XCTAssertEqual(evaluate("=SUBSTITUTE(\"a-b-c\",\"-\",\"+\",2)"), .text("a-b+c"))
        XCTAssertEqual(evaluate("=REPLACE(\"abcdef\",2,3,\"XY\")"), .text("aXYef"))
        XCTAssertEqual(evaluate("=FIND(\"c\",\"abcabc\")"), .number(3))
        XCTAssertEqual(evaluate("=SEARCH(\"C\",\"abcabc\")"), .number(3))
        XCTAssertEqual(evaluate("=FIND(\"C\",\"abcabc\")"), .error("#VALUE!"))
        XCTAssertEqual(evaluate("=CONCAT(\"a\",\"b\",1)"), .text("ab1"))
        XCTAssertEqual(evaluate("=TEXTJOIN(\"-\",TRUE,A1:A2)"), .text("North-South"))
        XCTAssertEqual(evaluate("=REPT(\"ab\",3)"), .text("ababab"))
        XCTAssertEqual(evaluate("=EXACT(\"a\",\"A\")"), .boolean(false))
        XCTAssertEqual(evaluate("=VALUE(\"12.5\")"), .number(12.5))
        XCTAssertEqual(evaluate("=TEXT(1234.5,\"#,##0.00\")"), .text("1,234.50"))
    }

    func testLookupFunctions() {
        XCTAssertEqual(evaluate("=VLOOKUP(\"East\",A1:B4,2,FALSE)"), .number(30))
        XCTAssertEqual(evaluate("=VLOOKUP(\"Nowhere\",A1:B4,2,FALSE)"), .error("#N/A"))
        XCTAssertEqual(evaluate("=MATCH(\"South\",A1:A4,0)"), .number(2))
        XCTAssertEqual(evaluate("=INDEX(B1:B4,3)"), .number(30))
        XCTAssertEqual(evaluate("=INDEX(A1:B4,2,2)"), .number(20))
        XCTAssertEqual(evaluate("=INDEX(B1:B4,MATCH(\"West\",A1:A4,0))"), .number(40))
        XCTAssertEqual(evaluate("=INDEX(B1:B4,9)"), .error("#REF!"))
        XCTAssertEqual(evaluate("=HLOOKUP(\"North\",A1:C1,1,FALSE)"), .text("North"))
    }

    func testConditionalAggregation() {
        XCTAssertEqual(evaluate("=COUNTIF(B1:B4,\">15\")"), .number(3))
        XCTAssertEqual(evaluate("=COUNTIF(A1:A4,\"South\")"), .number(1))
        XCTAssertEqual(evaluate("=COUNTIF(A1:A4,\"*st\")"), .number(2), "wildcards match East and West")
        XCTAssertEqual(evaluate("=SUMIF(B1:B4,\">15\")"), .number(90))
        XCTAssertEqual(evaluate("=SUMIF(A1:A4,\"North\",B1:B4)"), .number(10))
        XCTAssertEqual(evaluate("=COUNTIFS(A1:A4,\"East\",B1:B4,\">20\")"), .number(1))
        XCTAssertEqual(evaluate("=COUNTIFS(A1:A4,\"East\",B1:B4,\">50\")"), .number(0))
        XCTAssertEqual(evaluate("=SUMIFS(B1:B4,A1:A4,\"West\")"), .number(40))
        XCTAssertEqual(evaluate("=AVERAGEIF(B1:B4,\">15\")"), .number(30))
    }

    func testInformationFunctions() {
        XCTAssertEqual(evaluate("=ISBLANK(Z1)"), .boolean(true))
        XCTAssertEqual(evaluate("=ISBLANK(B1)"), .boolean(false))
        XCTAssertEqual(evaluate("=ISNUMBER(B1)"), .boolean(true))
        XCTAssertEqual(evaluate("=ISTEXT(A1)"), .boolean(true))
        XCTAssertEqual(evaluate("=ISERROR(1/0)"), .boolean(true))
        XCTAssertEqual(evaluate("=ISNA(NA())"), .boolean(true))
    }

    func testDateFunctions() {
        XCTAssertEqual(evaluate("=DATE(2026,9,16)"), .number(46281))
        XCTAssertEqual(evaluate("=YEAR(46281)"), .number(2026))
        XCTAssertEqual(evaluate("=MONTH(46281)"), .number(9))
        XCTAssertEqual(evaluate("=DAY(46281)"), .number(16))
        XCTAssertEqual(evaluate("=DAYS(46281,46271)"), .number(10))
        XCTAssertEqual(evaluate("=EOMONTH(46281,0)"), .number(46295), "30 September 2026")
        XCTAssertEqual(evaluate("=EDATE(46281,1)"), .number(46311), "16 October 2026")
    }

    func testUnknownFunctionIsANameError() {
        XCTAssertEqual(evaluate("=NOTAFUNCTION(1)"), .error("#NAME?"))
        XCTAssertEqual(evaluate("=SomeName"), .error("#NAME?"))
    }

    func testErrorsPropagate() {
        XCTAssertEqual(evaluate("=SUM(1,1/0)"), .error("#DIV/0!"))
        XCTAssertEqual(evaluate("=1+\"abc\""), .error("#VALUE!"))
    }

    // MARK: - Recalculation

    func testRecalculatesInDependencyOrder() {
        var workbook = makeWorkbook()
        // Deliberately stored in an order that a naive single pass gets wrong.
        workbook.sheets[0][10, 1] = Cell(value: .number(0), formula: "A11*2")
        workbook.sheets[0][11, 1] = Cell(value: .number(0), formula: "A12+1")
        workbook.sheets[0][12, 1] = Cell(value: .number(0), formula: "SUM(B1:B4)")

        let issues = Recalculator.recalculate(&workbook)
        XCTAssertTrue(issues.isEmpty)
        XCTAssertEqual(workbook.sheets[0][12, 1].value, .number(100))
        XCTAssertEqual(workbook.sheets[0][11, 1].value, .number(101))
        XCTAssertEqual(workbook.sheets[0][10, 1].value, .number(202))
    }

    func testRecalculatesAcrossSheets() {
        var workbook = makeWorkbook()
        workbook.sheets[1][2, 1] = Cell(formula: "Data!B1*2")
        workbook.sheets[0][20, 1] = Cell(formula: "Other!A2+1")

        Recalculator.recalculate(&workbook)
        XCTAssertEqual(workbook.sheets[1][2, 1].value, .number(20))
        XCTAssertEqual(workbook.sheets[0][20, 1].value, .number(21))
    }

    func testReportsCircularReferences() {
        var workbook = makeWorkbook()
        workbook.sheets[0][1, 5] = Cell(formula: "F1+1")
        workbook.sheets[0][1, 6] = Cell(formula: "E1+1")

        let issues = Recalculator.recalculate(&workbook)
        XCTAssertEqual(issues.count, 2)
        XCTAssertEqual(issues.first?.kind, .circularReference)
        XCTAssertEqual(workbook.sheets[0][1, 5].value, .error("#REF!"))
    }

    func testSelfReferenceIsCircular() {
        var workbook = makeWorkbook()
        workbook.sheets[0][1, 5] = Cell(formula: "E1+1")
        let issues = Recalculator.recalculate(&workbook)
        XCTAssertEqual(issues.count, 1)
    }

    func testIncrementalRecalculationTouchesOnlyDependents() {
        var workbook = makeWorkbook()
        workbook.sheets[0][10, 1] = Cell(formula: "SUM(B1:B4)")
        workbook.sheets[0][11, 1] = Cell(formula: "A10*2")
        workbook.sheets[0][12, 1] = Cell(formula: "C1")
        Recalculator.recalculate(&workbook)
        XCTAssertEqual(workbook.sheets[0][11, 1].value, .number(200))

        // A stale cached value on an unrelated formula proves it was skipped.
        workbook.sheets[0][12, 1].value = .text("stale")
        workbook.sheets[0][1, 2] = Cell(value: .number(50))
        Recalculator.recalculate(&workbook, changedCells: [(0, CellAddress(row: 1, column: 2))])

        XCTAssertEqual(workbook.sheets[0][10, 1].value, .number(140))
        XCTAssertEqual(workbook.sheets[0][11, 1].value, .number(280), "dependents update transitively")
        XCTAssertEqual(workbook.sheets[0][12, 1].value, .text("stale"), "unrelated formulas are left alone")
    }

    func testIncrementalRecalculationUpdatesTheEditedFormulaItself() {
        var workbook = makeWorkbook()
        workbook.sheets[0][10, 1] = Cell(formula: "B1+B2")
        Recalculator.recalculate(&workbook, changedCells: [(0, CellAddress(row: 10, column: 1))])
        XCTAssertEqual(workbook.sheets[0][10, 1].value, .number(30))
    }

    // MARK: - Translation

    func testShiftsRelativeReferencesOnly() {
        XCTAssertEqual(FormulaTranslator.shift("A1+$B$2", rowDelta: 1, columnDelta: 1), "B2+$B$2")
        XCTAssertEqual(FormulaTranslator.shift("SUM(A1:A5)", rowDelta: 2, columnDelta: 0), "SUM(A3:A7)")
        XCTAssertEqual(FormulaTranslator.shift("$A1", rowDelta: 3, columnDelta: 5), "$A4")
        XCTAssertEqual(FormulaTranslator.shift("A$1", rowDelta: 3, columnDelta: 1), "B$1")
    }

    func testDoesNotShiftFunctionNamesOrStrings() {
        XCTAssertEqual(FormulaTranslator.shift("LOG10(A1)", rowDelta: 1, columnDelta: 0), "LOG10(A2)")
        XCTAssertEqual(FormulaTranslator.shift("\"A1 stays\"&A1", rowDelta: 1, columnDelta: 0),
                       "\"A1 stays\"&A2")
        XCTAssertEqual(FormulaTranslator.shift("'Sheet A1'!A1", rowDelta: 1, columnDelta: 0),
                       "'Sheet A1'!A2")
    }

    func testShiftingOffTheSheetGivesAReferenceError() {
        XCTAssertEqual(FormulaTranslator.shift("A1", rowDelta: -5, columnDelta: 0), "#REF!")
    }

    func testAdjustsForInsertedAndDeletedRows() {
        XCTAssertEqual(FormulaTranslator.adjust("SUM($B$5:$B$9)", insertingRows: 3...3), "SUM($B$6:$B$10)")
        XCTAssertEqual(FormulaTranslator.adjust("A10", deletingRows: 2...3), "A8")
        XCTAssertEqual(FormulaTranslator.adjust("A2", deletingRows: 2...3), "#REF!")
        XCTAssertEqual(FormulaTranslator.adjust("C1", insertingColumns: 1...1), "D1")
    }
}
