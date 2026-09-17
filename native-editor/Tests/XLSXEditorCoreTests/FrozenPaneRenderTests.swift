import AppKit
import XCTest
@testable import XLSXEditorCore
@testable import XLSXKit

/// Frozen rows and columns own their part of the window. Nothing from the
/// scrolled body, including the selection, may be drawn across them.
///
/// The cells chosen here are the ones whose unclipped position would land
/// inside a frozen band, which is what made the bug visible.
final class FrozenPaneRenderTests: XCTestCase {
    private var document: SpreadsheetDocument!
    private var controller: SpreadsheetViewController!
    private var window: NSWindow!

    private static let frozenRows = 3
    private static let frozenColumns = 2
    private static let scroll = CGPoint(x: 300, y: 600)

    override func setUp() {
        super.setUp()
        var workbook = Workbook()
        for row in 1...80 {
            for column in 1...12 {
                workbook.sheets[0][row, column] = Cell(value: .text("r\(row)c\(column)"))
            }
        }
        workbook.sheets[0].freeze = FreezePane(columns: FrozenPaneRenderTests.frozenColumns,
                                               rows: FrozenPaneRenderTests.frozenRows)

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

    /// A render of the visible grid, with the scale needed to turn the view's
    /// points into the bitmap's pixels: on a Retina backing they differ by two.
    private struct Shot {
        let bitmap: NSBitmapImageRep
        let scale: CGFloat

        func pixels(_ range: Range<CGFloat>) -> Range<Int> {
            let low = Int((range.lowerBound * scale).rounded(.up))
            let high = Int((range.upperBound * scale).rounded(.down))
            return low..<max(low, high)
        }
    }

    private func render(selecting address: CellAddress) throws -> Shot {
        let scrollView = try XCTUnwrap(grid.enclosingScrollView)
        scrollView.contentView.scroll(to: FrozenPaneRenderTests.scroll)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        grid.select(CellRange(address), scroll: false)
        grid.displayIfNeeded()

        let visible = grid.visibleRect
        let bitmap = try XCTUnwrap(grid.bitmapImageRepForCachingDisplay(in: visible))
        grid.cacheDisplay(in: visible, to: bitmap)
        return Shot(bitmap: bitmap, scale: CGFloat(bitmap.pixelsWide) / visible.width)
    }

    // MARK: - What sits behind what

    /// Rows whose natural position falls inside the frozen row band once
    /// scrolled: exactly the ones that used to paint over it.
    private func rowsBehindTheFrozenBand() -> [Int] {
        let metrics = grid.metricsForTesting
        let top = FrozenPaneRenderTests.scroll.y + GridMetrics.headerHeight
        let bottom = FrozenPaneRenderTests.scroll.y + metrics.y(ofRow: FrozenPaneRenderTests.frozenRows + 1)
        return (1...80).filter { metrics.y(ofRow: $0) >= top && metrics.y(ofRow: $0) < bottom }
    }

    private func columnsBehindTheFrozenBand() -> [Int] {
        let metrics = grid.metricsForTesting
        let left = FrozenPaneRenderTests.scroll.x + GridMetrics.headerWidth
        let right = FrozenPaneRenderTests.scroll.x
            + metrics.x(ofColumn: FrozenPaneRenderTests.frozenColumns + 1)
        return (1...12).filter { metrics.x(ofColumn: $0) >= left && metrics.x(ofColumn: $0) < right }
    }

    /// The frozen bands in view points, measured from the top-left of the
    /// visible area, which is where the headers are drawn.
    private var frozenRowBandPoints: Range<CGFloat> {
        let top = GridMetrics.headerHeight + 1
        let bottom = grid.metricsForTesting.y(ofRow: FrozenPaneRenderTests.frozenRows + 1) - 1
        return top..<bottom
    }

    private var frozenColumnBandPoints: Range<CGFloat> {
        let left = GridMetrics.headerWidth + 1
        let right = grid.metricsForTesting.x(ofColumn: FrozenPaneRenderTests.frozenColumns + 1) - 1
        return left..<right
    }

    private func differences(_ a: Shot, _ b: Shot, rows: Range<Int>, columns: Range<Int>) -> Int {
        var count = 0
        for y in rows where y < min(a.bitmap.pixelsHigh, b.bitmap.pixelsHigh) {
            for x in columns where x < min(a.bitmap.pixelsWide, b.bitmap.pixelsWide) {
                guard let first = a.bitmap.colorAt(x: x, y: y),
                      let second = b.bitmap.colorAt(x: x, y: y) else { continue }
                if first != second { count += 1 }
            }
        }
        return count
    }

    // MARK: - Tests

    func testSelectionDoesNotPaintOverTheFrozenRows() throws {
        let rows = rowsBehindTheFrozenBand()
        try XCTSkipUnless(rows.count >= 2, "the setup should put rows behind the frozen band")

        let first = try render(selecting: CellAddress(row: rows[0], column: 6))
        let second = try render(selecting: CellAddress(row: rows[1], column: 6))
        let band = first.pixels(frozenRowBandPoints)
        let across = first.pixels(200..<700)

        XCTAssertGreaterThan(band.count, 20, "the band should cover real pixels")
        XCTAssertEqual(differences(first, second, rows: band, columns: across), 0,
                       "a body selection behind the frozen rows must not show through them")
    }

    func testSelectionDoesNotPaintOverTheFrozenColumns() throws {
        let columns = columnsBehindTheFrozenBand()
        try XCTSkipUnless(columns.count >= 2, "the setup should put columns behind the frozen band")

        let first = try render(selecting: CellAddress(row: 40, column: columns[0]))
        let second = try render(selecting: CellAddress(row: 40, column: columns[1]))
        let band = first.pixels(frozenColumnBandPoints)
        let down = first.pixels(100..<400)

        XCTAssertGreaterThan(band.count, 20)
        XCTAssertEqual(differences(first, second, rows: down, columns: band), 0,
                       "a body selection behind the frozen columns must not show through them")
    }

    func testTheFrozenRowsStillShowTheirOwnContent() throws {
        let shot = try render(selecting: CellAddress(a1: "F40")!)
        let band = shot.pixels(frozenRowBandPoints)

        var distinct = Set<String>()
        for y in band {
            for x in stride(from: 4, to: shot.bitmap.pixelsWide - 4, by: 7) {
                guard let color = shot.bitmap.colorAt(x: x, y: y) else { continue }
                distinct.insert("\(Int(color.redComponent * 255))-\(Int(color.greenComponent * 255))")
            }
        }
        XCTAssertGreaterThan(distinct.count, 2, "the frozen rows should still be drawing their text")
    }
}
