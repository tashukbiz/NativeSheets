import XCTest
@testable import XLSXKit

/// Checks a real workbook of your own, end to end.
///
/// Skipped unless `XLSX_CHECK_SOURCE` points at a file, so the suite stays
/// self-contained. `xcodebuild test` does not forward the shell environment to
/// the test process, so running this one takes `xctest` directly. See the
/// README.
final class ExternalWorkbookTests: XCTestCase {
    private func sourceWorkbook() throws -> Workbook {
        guard let path = ProcessInfo.processInfo.environment["XLSX_CHECK_SOURCE"] else {
            throw XCTSkip("set XLSX_CHECK_SOURCE to check a workbook of your own")
        }
        return try XLSXReader.read(contentsOf: URL(fileURLWithPath: NSString(string: path).expandingTildeInPath))
    }

    func testRoundTripsEveryCell() throws {
        let original = try sourceWorkbook()
        let reloaded = try XLSXReader.read(data: XLSXWriter.data(for: original))

        XCTAssertEqual(reloaded.sheets.map(\.name), original.sheets.map(\.name))
        var checked = 0
        for (index, sheet) in original.sheets.enumerated() {
            for (row, cells) in sheet.rows {
                for (column, cell) in cells.cells {
                    let address = CellAddress(row: row, column: column)
                    let after = reloaded.sheets[index][address]
                    XCTAssertEqual(after.value, cell.value, "\(sheet.name)!\(address.a1)")
                    XCTAssertEqual(after.formula, cell.formula, "\(sheet.name)!\(address.a1)")
                    XCTAssertEqual(after.styleIndex, cell.styleIndex, "\(sheet.name)!\(address.a1)")
                    checked += 1
                }
            }
            XCTAssertEqual(reloaded.sheets[index].freeze, sheet.freeze, sheet.name)
            XCTAssertEqual(reloaded.sheets[index].merges, sheet.merges, sheet.name)
        }
        print("round-tripped \(checked) cells across \(original.sheets.count) sheets")
    }

    /// Recomputing should land on the values the file already carries. Any
    /// mismatch is either a gap in the engine or a stale value in the file.
    func testRecalculationAgreesWithTheStoredValues() throws {
        var workbook = try sourceWorkbook()
        var stored: [String: CellValue] = [:]
        for sheet in workbook.sheets {
            for (row, cells) in sheet.rows {
                for (column, cell) in cells.cells where cell.formula != nil {
                    stored["\(sheet.name)!\(CellAddress(row: row, column: column).a1)"] = cell.value
                }
            }
        }

        let started = Date()
        let issues = Recalculator.recalculate(&workbook)
        print("recalculated \(stored.count) formulas in \(String(format: "%.3f", -started.timeIntervalSinceNow))s")
        for issue in issues.prefix(10) { print("  issue: \(issue.message)") }

        var mismatches: [String] = []
        for sheet in workbook.sheets {
            for (row, cells) in sheet.rows {
                for (column, cell) in cells.cells where cell.formula != nil {
                    let key = "\(sheet.name)!\(CellAddress(row: row, column: column).a1)"
                    guard let before = stored[key] else { continue }
                    // A formula whose result is "" is stored as a blank cell.
                    func normalized(_ value: CellValue) -> CellValue {
                        if case .text(let text) = value, text.isEmpty { return .empty }
                        return value
                    }
                    guard normalized(before) != normalized(cell.value) else { continue }
                    mismatches.append("\(key): stored \(before), computed \(cell.value)")
                }
            }
        }
        for mismatch in mismatches.prefix(10) { print("  mismatch: \(mismatch)") }
        XCTAssertEqual(mismatches.count, 0, "\(mismatches.count) formulas disagree with the stored values")
    }
}
