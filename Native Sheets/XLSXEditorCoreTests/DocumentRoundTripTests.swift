import AppKit
import XCTest
@testable import XLSXEditorCore
@testable import XLSXKit

/// The whole journey a user takes: open a file, change it, save it, open the
/// saved file again.
final class DocumentRoundTripTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("doctest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeSourceFile() throws -> URL {
        var workbook = Workbook()
        try workbook.renameSheet(at: 0, to: "Budget")
        try workbook.insertSheet(named: "Notes", at: 1)
        workbook.sheets[0][1, 1] = Cell(value: .text("Item"))
        workbook.sheets[0][1, 2] = Cell(value: .text("Cost"))
        for row in 2...4 {
            workbook.sheets[0][row, 1] = Cell(value: .text("item\(row - 1)"))
            workbook.sheets[0][row, 2] = Cell(value: .number(Double(row) * 10))
        }
        workbook.sheets[0][5, 2] = Cell(formula: "SUM(B2:B4)")
        workbook.sheets[1][1, 1] = Cell(value: .text("second page"))
        Recalculator.recalculate(&workbook)

        let url = directory.appendingPathComponent("source.xlsx")
        try XLSXWriter.write(workbook, to: url)
        return url
    }

    func testOpenEditSaveReopen() throws {
        let source = try makeSourceFile()

        let document = try SpreadsheetDocument(contentsOf: source, ofType: "org.openxmlformats.spreadsheetml.sheet")
        XCTAssertEqual(document.workbook.sheets.map(\.name), ["Budget", "Notes"])
        XCTAssertEqual(document.workbook.sheets[0][5, 2].value, .number(90))

        // Edit a value, add a sheet, and rename one.
        document.perform("edit", changedCells: [(0, CellAddress(row: 2, column: 2))]) { workbook in
            workbook.sheets[0][2, 2].value = .number(100)
        }
        XCTAssertEqual(document.workbook.sheets[0][5, 2].value, .number(170),
                       "the total should follow the edit")

        document.perform("add") { try? $0.insertSheet(named: "Summary", at: 2) }
        document.perform("rename") { try? $0.renameSheet(at: 1, to: "Remarks") }

        let destination = directory.appendingPathComponent("saved.xlsx")
        try document.write(to: destination, ofType: "org.openxmlformats.spreadsheetml.sheet",
                           for: .saveAsOperation, originalContentsURL: nil)

        let reopened = try SpreadsheetDocument(contentsOf: destination,
                                               ofType: "org.openxmlformats.spreadsheetml.sheet")
        XCTAssertEqual(reopened.workbook.sheets.map(\.name), ["Budget", "Remarks", "Summary"])
        XCTAssertEqual(reopened.workbook.sheets[0][2, 2].value, .number(100))
        XCTAssertEqual(reopened.workbook.sheets[0][5, 2].value, .number(170))
        XCTAssertEqual(reopened.workbook.sheets[0][5, 2].formula, "SUM(B2:B4)")
        XCTAssertEqual(reopened.workbook.sheets[1][1, 1].value, .text("second page"))
    }

    func testUndoAfterSaveStillWorks() throws {
        let source = try makeSourceFile()
        let document = try SpreadsheetDocument(contentsOf: source, ofType: "org.openxmlformats.spreadsheetml.sheet")

        document.perform("edit", changedCells: [(0, CellAddress(row: 2, column: 1))]) {
            $0.sheets[0][2, 1].value = .text("renamed")
        }
        try document.write(to: directory.appendingPathComponent("a.xlsx"),
                           ofType: "org.openxmlformats.spreadsheetml.sheet",
                           for: .saveAsOperation, originalContentsURL: nil)

        document.undoManager?.undo()
        XCTAssertEqual(document.workbook.sheets[0][2, 1].value, .text("item1"))
    }

    func testDeletingASheetSurvivesASave() throws {
        let source = try makeSourceFile()
        let document = try SpreadsheetDocument(contentsOf: source, ofType: "org.openxmlformats.spreadsheetml.sheet")

        document.perform("delete", reloadingSheets: true) { try? $0.removeSheet(at: 1) }
        let destination = directory.appendingPathComponent("deleted.xlsx")
        try document.write(to: destination, ofType: "org.openxmlformats.spreadsheetml.sheet",
                           for: .saveAsOperation, originalContentsURL: nil)

        let reopened = try SpreadsheetDocument(contentsOf: destination,
                                               ofType: "org.openxmlformats.spreadsheetml.sheet")
        XCTAssertEqual(reopened.workbook.sheets.map(\.name), ["Budget"])
    }

    /// What File > New produces has to be saveable as a valid workbook.
    func testANewDocumentSavesAndReopens() throws {
        let document = SpreadsheetDocument()
        XCTAssertEqual(document.workbook.sheets.count, 1)

        document.perform("type", changedCells: [(0, CellAddress(row: 1, column: 1))]) {
            $0.sheets[0][1, 1].value = .text("hello")
        }
        document.perform("add", reloadingSheets: true) { try? $0.insertSheet(named: "Second", at: 1) }

        let destination = directory.appendingPathComponent("new.xlsx")
        try document.write(to: destination, ofType: "org.openxmlformats.spreadsheetml.sheet",
                           for: .saveAsOperation, originalContentsURL: nil)

        let reopened = try SpreadsheetDocument(contentsOf: destination,
                                               ofType: "org.openxmlformats.spreadsheetml.sheet")
        XCTAssertEqual(reopened.workbook.sheets.map(\.name), ["Sheet1", "Second"])
        XCTAssertEqual(reopened.workbook.sheets[0][1, 1].value, .text("hello"))
    }

    func testAnUnreadableFileReportsAnError() {
        let broken = directory.appendingPathComponent("broken.xlsx")
        try? Data("not a spreadsheet".utf8).write(to: broken)
        XCTAssertThrowsError(
            try SpreadsheetDocument(contentsOf: broken, ofType: "org.openxmlformats.spreadsheetml.sheet")
        )
    }

    /// The bundle has to name a document class that actually exists, or every
    /// open fails with an unhelpful alert.
    func testTheBundleDeclaresAWorkingDocumentClass() throws {
        let plist = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Native Sheets/Info.plist")
        let contents = try XCTUnwrap(NSDictionary(contentsOf: plist))
        let types = try XCTUnwrap(contents["CFBundleDocumentTypes"] as? [[String: Any]])
        let className = try XCTUnwrap(types.first?["NSDocumentClass"] as? String)

        XCTAssertNotNil(NSClassFromString(className),
                        "Info.plist names \(className), which the runtime cannot find")
        XCTAssertTrue(NSClassFromString(className) is NSDocument.Type)
    }
}
