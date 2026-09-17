import AppKit
import XCTest
@testable import XLSXEditorCore
@testable import XLSXKit

/// A cell restricted to a list of values offers them as a dropdown.
final class DataValidationTests: XCTestCase {
    private var document: SpreadsheetDocument!
    private var controller: SpreadsheetViewController!
    private var window: NSWindow!

    private static let stages = ["Research incomplete", "Draft ready", "Contacted", "Agreed"]

    override func setUp() {
        super.setUp()
        var workbook = Workbook()
        workbook.sheets[0][1, 1] = Cell(value: .text("Name"))
        workbook.sheets[0][1, 2] = Cell(value: .text("Stage"))
        for row in 2...5 {
            workbook.sheets[0][row, 1] = Cell(value: .text("creator\(row)"))
            workbook.sheets[0][row, 2] = Cell(value: .text("Research incomplete"))
        }
        workbook.sheets[0].validations = [
            DataValidation(ranges: [CellRange(a1: "B2:B5")!], values: DataValidationTests.stages)
        ]

        document = SpreadsheetDocument()
        document.adopt(workbook)
        controller = SpreadsheetViewController()
        window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 900, height: 600),
                          styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.contentViewController = controller
        controller.document = document
        window.layoutIfNeeded()
    }

    private var grid: GridView { controller.gridViewForTesting }

    // MARK: - The dropdown

    func testTheButtonAppearsOnlyOnAValidatedCell() {
        grid.select(CellRange(CellAddress(a1: "B3")!))
        XCTAssertNotNil(grid.validationButtonFrame())

        grid.select(CellRange(CellAddress(a1: "A3")!))
        XCTAssertNil(grid.validationButtonFrame(), "an unrestricted cell has no dropdown")

        grid.select(CellRange(CellAddress(a1: "B9")!))
        XCTAssertNil(grid.validationButtonFrame(), "outside the validated range there is no dropdown")
    }

    func testTheButtonSitsInsideItsCell() throws {
        let address = CellAddress(a1: "B3")!
        grid.select(CellRange(address))
        let button = try XCTUnwrap(grid.validationButtonFrame())
        let cell = grid.metricsForTesting.rect(of: address)

        XCTAssertTrue(cell.contains(button), "the button must stay within the cell")
        XCTAssertEqual(button.maxX, cell.maxX - 1, accuracy: 0.5, "it belongs at the trailing edge")
    }

    func testTheMenuOffersEveryAllowedValue() throws {
        grid.select(CellRange(CellAddress(a1: "B3")!))
        let menu = try XCTUnwrap(grid.validationMenu())

        let titles = menu.items.filter { !$0.isSeparatorItem }.map(\.title)
        XCTAssertEqual(titles, DataValidationTests.stages + ["Clear"])
        XCTAssertEqual(menu.items.first { $0.state == .on }?.title, "Research incomplete",
                       "the current value should be ticked")
    }

    func testChoosingAValueWritesItToTheCell() throws {
        let address = CellAddress(a1: "B3")!
        grid.select(CellRange(address))
        let menu = try XCTUnwrap(grid.validationMenu())
        let item = try XCTUnwrap(menu.items.first { $0.title == "Agreed" })

        grid.chooseValidationValue(item)
        XCTAssertEqual(document.workbook.sheets[0][address].value, .text("Agreed"))
    }

    func testChoosingClearEmptiesTheCell() throws {
        let address = CellAddress(a1: "B3")!
        grid.select(CellRange(address))
        let menu = try XCTUnwrap(grid.validationMenu())
        let item = try XCTUnwrap(menu.items.first { $0.title == "Clear" })

        grid.chooseValidationValue(item)
        XCTAssertEqual(document.workbook.sheets[0][address].value, .empty)
    }

    func testClickingTheButtonIsNotTreatedAsACellClick() throws {
        grid.select(CellRange(CellAddress(a1: "B3")!))
        let button = try XCTUnwrap(grid.validationButtonFrame())

        // A click just outside the button selects the cell under it as usual.
        let beside = CGPoint(x: button.minX - 6, y: button.midY)
        grid.mouseDown(with: .click(at: beside, in: grid))
        grid.mouseUp(with: .click(at: beside, in: grid))
        XCTAssertEqual(grid.activeCell, CellAddress(a1: "B3")!)
    }

    /// A validated cell inside a frozen band keeps its button under the
    /// pointer, even though that band is pinned while the rest scrolls.
    func testTheButtonFollowsACellInAFrozenBand() throws {
        var workbook = document.workbook
        workbook.sheets[0].freeze = FreezePane(columns: 0, rows: 4)
        for row in 20...60 {
            workbook.sheets[0][row, 1] = Cell(value: .text("filler\(row)"))
        }
        document.adopt(workbook)

        let address = CellAddress(a1: "B3")!
        grid.select(CellRange(address), scroll: false)
        let unscrolled = try XCTUnwrap(grid.validationButtonFrame())

        let scrollView = try XCTUnwrap(grid.enclosingScrollView)
        scrollView.contentView.scroll(to: CGPoint(x: 0, y: 260))
        scrollView.reflectScrolledClipView(scrollView.contentView)

        let scrolled = try XCTUnwrap(grid.validationButtonFrame())
        XCTAssertEqual(scrolled.minY - unscrolled.minY, 260, accuracy: 1,
                       "a frozen cell's button travels with the scroll offset")
        XCTAssertEqual(scrolled.minX, unscrolled.minX, accuracy: 1)
    }

    func testChoosingAValueIsUndoable() throws {
        let address = CellAddress(a1: "B3")!
        grid.select(CellRange(address))
        let menu = try XCTUnwrap(grid.validationMenu())
        grid.chooseValidationValue(try XCTUnwrap(menu.items.first { $0.title == "Contacted" }))
        XCTAssertEqual(document.workbook.sheets[0][address].value, .text("Contacted"))

        document.undoManager?.undo()
        XCTAssertEqual(document.workbook.sheets[0][address].value, .text("Research incomplete"))
    }
}
