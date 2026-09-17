import AppKit
import XCTest
@testable import XLSXEditorCore
@testable import XLSXKit

/// Drives the real views without launching the app: a window is created
/// off screen, events are delivered to the grid, and the result is checked
/// against the document.
final class GridViewTests: XCTestCase {
    private var document: SpreadsheetDocument!
    private var controller: SpreadsheetViewController!
    private var window: NSWindow!

    override func setUp() {
        super.setUp()
        document = SpreadsheetDocument()
        var workbook = Workbook()
        try? workbook.renameSheet(at: 0, to: "Data")
        try? workbook.insertSheet(named: "Notes", at: 1)
        for row in 1...6 {
            workbook.sheets[0][row, 1] = Cell(value: .text("label\(row)"))
            workbook.sheets[0][row, 2] = Cell(value: .number(Double(row) * 100))
        }
        workbook.sheets[0][7, 2] = Cell(formula: "SUM(B1:B6)")
        Recalculator.recalculate(&workbook)
        document.adopt(workbook)

        controller = SpreadsheetViewController()
        window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 900, height: 600),
                          styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.contentViewController = controller
        controller.document = document
        window.layoutIfNeeded()
    }

    override func tearDown() {
        window = nil
        controller = nil
        document = nil
        super.tearDown()
    }

    private var grid: GridView { controller.gridViewForTesting }

    // MARK: - Selection and navigation

    func testStartsAtTheFirstCell() {
        XCTAssertEqual(grid.activeCell, CellAddress(row: 1, column: 1))
    }

    func testArrowKeysMoveTheSelection() {
        grid.keyDown(with: .arrow(.down))
        grid.keyDown(with: .arrow(.right))
        XCTAssertEqual(grid.activeCell, CellAddress(row: 2, column: 2))

        grid.keyDown(with: .arrow(.up))
        XCTAssertEqual(grid.activeCell, CellAddress(row: 1, column: 2))
    }

    func testTheSelectionCannotLeaveTheSheet() {
        grid.keyDown(with: .arrow(.up))
        grid.keyDown(with: .arrow(.left))
        XCTAssertEqual(grid.activeCell, CellAddress(row: 1, column: 1))
    }

    func testShiftArrowExtendsTheSelection() {
        grid.keyDown(with: .arrow(.down, shift: true))
        grid.keyDown(with: .arrow(.down, shift: true))
        XCTAssertEqual(grid.selection.a1, "A1:A3")
        XCTAssertEqual(grid.activeCell, CellAddress(row: 1, column: 1), "the anchor stays put")
    }

    func testCommandArrowJumpsToTheEdgeOfTheData() {
        grid.keyDown(with: .arrow(.down, command: true))
        XCTAssertEqual(grid.activeCell, CellAddress(row: 6, column: 1))
    }

    func testClickingSelectsACell() {
        grid.select(CellRange(CellAddress(row: 1, column: 1)))
        let point = grid.centerOfCell(CellAddress(row: 3, column: 2))
        grid.mouseDown(with: .click(at: point, in: grid))
        grid.mouseUp(with: .click(at: point, in: grid))
        XCTAssertEqual(grid.activeCell, CellAddress(row: 3, column: 2))
    }

    func testDraggingSelectsARange() {
        let start = grid.centerOfCell(CellAddress(row: 2, column: 1))
        let end = grid.centerOfCell(CellAddress(row: 4, column: 2))
        grid.mouseDown(with: .click(at: start, in: grid))
        grid.mouseDragged(with: .click(at: end, in: grid))
        grid.mouseUp(with: .click(at: end, in: grid))
        XCTAssertEqual(grid.selection.a1, "A2:B4")
    }

    func testClickingAColumnHeaderSelectsTheColumn() {
        let point = CGPoint(x: grid.centerOfCell(CellAddress(row: 1, column: 2)).x,
                            y: GridMetrics.headerHeight / 2)
        grid.mouseDown(with: .click(at: point, in: grid))
        grid.mouseUp(with: .click(at: point, in: grid))
        XCTAssertEqual(grid.selection.columns, 2...2)
        XCTAssertGreaterThan(grid.selection.rowCount, 50, "the whole column should be selected")
    }

    func testClickingARowHeaderSelectsTheRow() {
        let point = CGPoint(x: GridMetrics.headerWidth / 2,
                            y: grid.centerOfCell(CellAddress(row: 3, column: 1)).y)
        grid.mouseDown(with: .click(at: point, in: grid))
        grid.mouseUp(with: .click(at: point, in: grid))
        XCTAssertEqual(grid.selection.rows, 3...3)
        XCTAssertGreaterThan(grid.selection.columnCount, 20)
    }

    // MARK: - Editing

    func testTypingEditsTheCell() {
        grid.select(CellRange(CellAddress(row: 1, column: 3)))
        grid.keyDown(with: .character("7"))
        XCTAssertTrue(grid.isEditing)
        XCTAssertEqual(grid.editingText, "7")

        grid.setEditingText("725")
        grid.commitEditing(moving: .down)

        XCTAssertEqual(document.workbook.sheets[0][1, 3].value, .number(725))
        XCTAssertEqual(grid.activeCell, CellAddress(row: 2, column: 3), "Return moves down")
        XCTAssertFalse(grid.isEditing)
    }

    func testReturnOpensAndClosesTheEditor() {
        grid.select(CellRange(CellAddress(row: 1, column: 1)))
        grid.keyDown(with: .returnKey)
        XCTAssertTrue(grid.isEditing)
        XCTAssertEqual(grid.editingText, "label1", "the editor opens on the existing value")
    }

    func testEscapeAbandonsTheEdit() {
        grid.select(CellRange(CellAddress(row: 1, column: 1)))
        grid.beginEditing(at: CellAddress(row: 1, column: 1))
        grid.setEditingText("discarded")
        grid.cancelEditing()
        XCTAssertEqual(document.workbook.sheets[0][1, 1].value, .text("label1"))
    }

    func testEnteringAFormulaComputesAndRecalculates() {
        grid.select(CellRange(CellAddress(row: 8, column: 2)))
        grid.beginEditing(at: CellAddress(row: 8, column: 2))
        grid.setEditingText("=B7*2")
        grid.commitEditing(moving: .stay)

        XCTAssertEqual(document.workbook.sheets[0][8, 2].formula, "B7*2")
        XCTAssertEqual(document.workbook.sheets[0][8, 2].value, .number(4200))
    }

    func testEditingAPrecedentUpdatesItsDependents() {
        grid.select(CellRange(CellAddress(row: 1, column: 2)))
        grid.beginEditing(at: CellAddress(row: 1, column: 2))
        grid.setEditingText("1000")
        grid.commitEditing(moving: .stay)

        XCTAssertEqual(document.workbook.sheets[0][7, 2].value, .number(3000),
                       "the SUM should follow its inputs")
    }

    func testDeleteClearsTheSelectionButKeepsFormatting() {
        document.perform("style") { workbook in
            workbook.sheets[0][1, 1].styleIndex = workbook.styles.applying(.bold(true), to: 0)
        }
        let styled = document.workbook.sheets[0][1, 1].styleIndex

        grid.select(CellRange(start: CellAddress(row: 1, column: 1), end: CellAddress(row: 2, column: 1)))
        grid.keyDown(with: .deleteKey)

        XCTAssertEqual(document.workbook.sheets[0][1, 1].value, .empty)
        XCTAssertEqual(document.workbook.sheets[0][2, 1].value, .empty)
        XCTAssertEqual(document.workbook.sheets[0][1, 1].styleIndex, styled)
    }

    func testUndoAndRedoRestoreCellContents() {
        grid.select(CellRange(CellAddress(row: 1, column: 1)))
        grid.beginEditing(at: CellAddress(row: 1, column: 1))
        grid.setEditingText("changed")
        grid.commitEditing(moving: .stay)
        XCTAssertEqual(document.workbook.sheets[0][1, 1].value, .text("changed"))

        document.undoManager?.undo()
        XCTAssertEqual(document.workbook.sheets[0][1, 1].value, .text("label1"))

        document.undoManager?.redo()
        XCTAssertEqual(document.workbook.sheets[0][1, 1].value, .text("changed"))
    }

    // MARK: - Clipboard

    func testCopyAndPasteMoveAGridOfValues() {
        grid.select(CellRange(start: CellAddress(row: 1, column: 1), end: CellAddress(row: 2, column: 2)))
        controller.copySelection()

        grid.select(CellRange(CellAddress(row: 10, column: 4)))
        controller.paste()

        XCTAssertEqual(document.workbook.sheets[0][10, 4].value, .text("label1"))
        XCTAssertEqual(document.workbook.sheets[0][10, 5].value, .number(100))
        XCTAssertEqual(document.workbook.sheets[0][11, 4].value, .text("label2"))
        XCTAssertEqual(document.workbook.sheets[0][11, 5].value, .number(200))
        XCTAssertEqual(grid.selection.a1, "D10:E11", "the pasted block ends up selected")
    }

    func testCutClearsTheSource() {
        grid.select(CellRange(CellAddress(row: 1, column: 1)))
        controller.cutSelection()
        XCTAssertEqual(document.workbook.sheets[0][1, 1].value, .empty)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "label1")
    }

    // MARK: - Structure

    func testInsertingRowsThroughTheControllerShiftsData() {
        grid.select(CellRange(CellAddress(row: 2, column: 1)))
        controller.insertRows()
        XCTAssertEqual(document.workbook.sheets[0][3, 1].value, .text("label2"))
        XCTAssertEqual(document.workbook.sheets[0][2, 1].value, .empty)
    }

    func testResizingAColumnIsRecordedAndUndoable() {
        let original = document.workbook.sheets[0].width(ofColumn: 1)
        controller.gridView(grid, didResizeColumn: 1, to: 33)
        XCTAssertEqual(document.workbook.sheets[0].width(ofColumn: 1), 33)

        document.undoManager?.undo()
        XCTAssertEqual(document.workbook.sheets[0].width(ofColumn: 1), original)
    }

    func testSwitchingSheetsShowsTheOtherSheet() {
        document.selectSheet(at: 1)
        XCTAssertEqual(document.activeSheet.name, "Notes")
        XCTAssertEqual(grid.activeCell, CellAddress(row: 1, column: 1), "selection resets on a new sheet")
    }

    func testAddingASheetThroughTheControllerSelectsIt() {
        controller.addSheet()
        XCTAssertEqual(document.workbook.sheets.count, 3)
        XCTAssertEqual(document.activeSheetIndex, 1)
    }

    func testStyleToggleAppliesToTheWholeSelection() {
        grid.select(CellRange(start: CellAddress(row: 1, column: 1), end: CellAddress(row: 3, column: 1)))
        controller.applyStyle(.bold(true), named: "Bold")

        for row in 1...3 {
            let index = document.workbook.sheets[0][row, 1].styleIndex
            XCTAssertTrue(document.workbook.styles.font(forStyle: index).bold, "row \(row)")
        }
        XCTAssertTrue(controller.selectionHas(\.bold))
    }

    func testFreezingPanesAtTheSelection() {
        grid.select(CellRange(CellAddress(row: 3, column: 2)))
        controller.toggleFreeze()
        XCTAssertEqual(document.workbook.sheets[0].freeze, FreezePane(columns: 1, rows: 2))

        controller.toggleFreeze()
        XCTAssertNil(document.workbook.sheets[0].freeze)
    }

    // MARK: - Rendering

    func testTheGridRendersItsContent() throws {
        let image = try XCTUnwrap(grid.renderForTesting(size: CGSize(width: 700, height: 420)))
        XCTAssertGreaterThan(image.size.width, 0)

        // A blank render would mean the draw path never ran.
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: image.tiffRepresentation ?? Data()))
        var distinctColors = Set<String>()
        for x in stride(from: 4, to: Int(bitmap.pixelsWide), by: 17) {
            for y in stride(from: 4, to: Int(bitmap.pixelsHigh), by: 17) {
                guard let color = bitmap.colorAt(x: x, y: y) else { continue }
                distinctColors.insert("\(Int(color.redComponent * 255))-\(Int(color.greenComponent * 255))")
            }
        }
        XCTAssertGreaterThan(distinctColors.count, 3, "the grid should draw lines, headers and text")
    }
}
