import AppKit
import XLSXKit

/// Maps between sheet coordinates and view coordinates.
///
/// Row and column offsets are kept as running sums so that hit testing and the
/// visible-range calculation are binary searches rather than scans, which is
/// what lets the grid handle a sheet with a hundred thousand rows.
struct GridMetrics {
    static let headerHeight: CGFloat = 24
    static let headerWidth: CGFloat = 52
    /// Grab area on a header divider for resizing.
    static let resizeHandle: CGFloat = 4
    static let minimumColumnWidth: CGFloat = 16
    static let minimumRowHeight: CGFloat = 12

    /// Empty space kept past the used range so there is always somewhere to
    /// scroll and type.
    private static let rowMargin = 60
    private static let columnMargin = 12

    private(set) var rowCount: Int
    private(set) var columnCount: Int
    private var columnOffsets: [CGFloat]
    private var rowOffsets: [CGFloat]

    init(sheet: Worksheet, extraRows: Int = 0, extraColumns: Int = 0) {
        let extent = sheet.usedExtent
        rowCount = max(extent.rows + GridMetrics.rowMargin, 100, extraRows)
        columnCount = max(extent.columns + GridMetrics.columnMargin, 26, extraColumns)

        columnOffsets = [0]
        columnOffsets.reserveCapacity(columnCount + 1)
        var x: CGFloat = 0
        for column in 1...columnCount {
            x += GridMetrics.pixels(forColumnWidth: sheet.width(ofColumn: column))
            columnOffsets.append(x)
        }

        rowOffsets = [0]
        rowOffsets.reserveCapacity(rowCount + 1)
        var y: CGFloat = 0
        for row in 1...rowCount {
            y += GridMetrics.pixels(forRowHeight: sheet.height(ofRow: row))
            rowOffsets.append(y)
        }
    }

    /// Column widths are stored in character units; this is the conversion the
    /// format documents, for the default font.
    static func pixels(forColumnWidth width: Double) -> CGFloat {
        width <= 0 ? 0 : CGFloat((width * 7).rounded() + 5)
    }

    static func columnWidth(forPixels pixels: CGFloat) -> Double {
        max(0, (Double(pixels) - 5) / 7)
    }

    /// Row heights are stored in points.
    static func pixels(forRowHeight points: Double) -> CGFloat {
        points <= 0 ? 0 : CGFloat(points * 4 / 3)
    }

    static func rowHeight(forPixels pixels: CGFloat) -> Double {
        max(0, Double(pixels) * 3 / 4)
    }

    // MARK: - Geometry

    var contentSize: CGSize {
        CGSize(width: GridMetrics.headerWidth + (columnOffsets.last ?? 0),
               height: GridMetrics.headerHeight + (rowOffsets.last ?? 0))
    }

    func x(ofColumn column: Int) -> CGFloat {
        GridMetrics.headerWidth + columnOffsets[min(max(column - 1, 0), columnOffsets.count - 1)]
    }

    func y(ofRow row: Int) -> CGFloat {
        GridMetrics.headerHeight + rowOffsets[min(max(row - 1, 0), rowOffsets.count - 1)]
    }

    func width(ofColumn column: Int) -> CGFloat {
        guard column >= 1, column < columnOffsets.count else { return 0 }
        return columnOffsets[column] - columnOffsets[column - 1]
    }

    func height(ofRow row: Int) -> CGFloat {
        guard row >= 1, row < rowOffsets.count else { return 0 }
        return rowOffsets[row] - rowOffsets[row - 1]
    }

    func rect(of address: CellAddress) -> CGRect {
        CGRect(x: x(ofColumn: address.column), y: y(ofRow: address.row),
               width: width(ofColumn: address.column), height: height(ofRow: address.row))
    }

    func rect(of range: CellRange) -> CGRect {
        let topLeft = rect(of: range.start)
        let bottomRight = rect(of: range.end)
        return CGRect(x: topLeft.minX, y: topLeft.minY,
                      width: bottomRight.maxX - topLeft.minX,
                      height: bottomRight.maxY - topLeft.minY)
    }

    // MARK: - Hit testing

    func column(atX position: CGFloat) -> Int {
        GridMetrics.index(in: columnOffsets, offset: position - GridMetrics.headerWidth, limit: columnCount)
    }

    func row(atY position: CGFloat) -> Int {
        GridMetrics.index(in: rowOffsets, offset: position - GridMetrics.headerHeight, limit: rowCount)
    }

    func address(at point: CGPoint) -> CellAddress {
        CellAddress(row: row(atY: point.y), column: column(atX: point.x))
    }

    private static func index(in offsets: [CGFloat], offset: CGFloat, limit: Int) -> Int {
        guard offset > 0 else { return 1 }
        var low = 0
        var high = offsets.count - 1
        while low < high {
            let middle = (low + high + 1) / 2
            if offsets[middle] <= offset { low = middle } else { high = middle - 1 }
        }
        return min(low + 1, limit)
    }

    /// The cells that intersect a rectangle, for drawing only what is on screen.
    func visibleRange(in rect: CGRect) -> CellRange {
        CellRange(
            start: CellAddress(row: row(atY: rect.minY), column: column(atX: rect.minX)),
            end: CellAddress(row: row(atY: rect.maxY), column: column(atX: rect.maxX))
        )
    }

    /// A column whose right edge is within grabbing distance of `position`.
    func columnDivider(nearX position: CGFloat) -> Int? {
        let column = self.column(atX: position + GridMetrics.resizeHandle)
        guard column >= 1 else { return nil }
        return abs(x(ofColumn: column) + width(ofColumn: column) - position) <= GridMetrics.resizeHandle
            ? column : nil
    }

    func rowDivider(nearY position: CGFloat) -> Int? {
        let row = self.row(atY: position + GridMetrics.resizeHandle)
        guard row >= 1 else { return nil }
        return abs(y(ofRow: row) + height(ofRow: row) - position) <= GridMetrics.resizeHandle ? row : nil
    }
}
