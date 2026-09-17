import Foundation

/// The frozen top-left region of a sheet view.
public struct FreezePane: Hashable, Sendable {
    public var columns: Int
    public var rows: Int

    public init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
    }
}

/// A run of columns sharing a width, matching the file's `<col min max>` spans.
public struct ColumnSpan: Sendable {
    public var first: Int
    public var last: Int
    public var width: Double?
    public var styleIndex: Int?
    public var hidden: Bool

    public init(first: Int, last: Int, width: Double?, styleIndex: Int? = nil, hidden: Bool = false) {
        self.first = first
        self.last = last
        self.width = width
        self.styleIndex = styleIndex
        self.hidden = hidden
    }
}

/// One page of the workbook.
public struct Worksheet: Sendable {
    public var name: String
    public var rows: [Int: Row] = [:]
    public var columns: [ColumnSpan] = []
    public var merges: [CellRange] = []
    /// List restrictions, parsed for display. The underlying part is preserved
    /// verbatim, so validations the editor does not model still survive a save.
    public var validations: [DataValidation] = []
    public var freeze: FreezePane?
    public var tabColor: String?
    public var showGridLines: Bool = true
    /// Points, as stored in the file. The grid converts to pixels.
    public var defaultRowHeight: Double = 15
    /// Character units, as stored in the file.
    public var defaultColumnWidth: Double = 8.43

    /// Identity inside the package, needed to rewrite the part in place.
    var partName: String = ""
    var relationshipID: String = ""
    var sheetID: Int = 1
    /// Element prefix used by the source part, empty for a default namespace.
    var namespacePrefix: String = ""

    /// Worksheet children the editor does not model (auto filters, data
    /// validation, table parts, page setup), kept verbatim and re-emitted in
    /// schema order on save.
    var preserved: [String: String] = [:]

    public init(name: String) {
        self.name = name
    }

    // MARK: - Cell access

    public subscript(address: CellAddress) -> Cell {
        get { rows[address.row]?.cells[address.column] ?? Cell() }
        set {
            if newValue.isDefault {
                guard rows[address.row] != nil else { return }
                rows[address.row]?.cells.removeValue(forKey: address.column)
                if rows[address.row]?.isDefault == true, rows[address.row]?.cells.isEmpty == true {
                    rows.removeValue(forKey: address.row)
                }
            } else {
                rows[address.row, default: Row()].cells[address.column] = newValue
            }
        }
    }

    public subscript(row: Int, column: Int) -> Cell {
        get { self[CellAddress(row: row, column: column)] }
        set { self[CellAddress(row: row, column: column)] = newValue }
    }

    // MARK: - Extent

    /// The last row and column holding anything, 0 when the sheet is empty.
    public var usedExtent: (rows: Int, columns: Int) {
        var lastRow = 0
        var lastColumn = 0
        for (index, row) in rows {
            let populated = row.cells.filter { !$0.value.isDefault }
            if !populated.isEmpty || !row.isDefault {
                lastRow = max(lastRow, index)
            }
            for (column, cell) in populated where !cell.isDefault {
                lastColumn = max(lastColumn, column)
            }
        }
        for span in columns where span.width != nil {
            lastColumn = max(lastColumn, min(span.last, span.first + 1024))
        }
        for merge in merges {
            lastRow = max(lastRow, merge.end.row)
            lastColumn = max(lastColumn, merge.end.column)
        }
        return (lastRow, lastColumn)
    }

    public var usedRange: CellRange? {
        let extent = usedExtent
        guard extent.rows > 0, extent.columns > 0 else { return nil }
        return CellRange(start: CellAddress(row: 1, column: 1),
                         end: CellAddress(row: extent.rows, column: extent.columns))
    }

    // MARK: - Geometry

    public func width(ofColumn column: Int) -> Double {
        for span in columns where column >= span.first && column <= span.last {
            if span.hidden { return 0 }
            if let width = span.width { return width }
        }
        return defaultColumnWidth
    }

    public mutating func setWidth(_ width: Double, forColumn column: Int) {
        splitSpans(around: column)
        if let index = columns.firstIndex(where: { $0.first == column && $0.last == column }) {
            columns[index].width = width
            columns[index].hidden = false
        } else {
            columns.append(ColumnSpan(first: column, last: column, width: width))
            columns.sort { $0.first < $1.first }
        }
    }

    /// Narrows any span covering `column` down to a run the column owns alone,
    /// so a width change cannot leak into its neighbours.
    private mutating func splitSpans(around column: Int) {
        var result: [ColumnSpan] = []
        for span in columns {
            guard column >= span.first, column <= span.last, span.first != span.last else {
                result.append(span)
                continue
            }
            if span.first < column {
                result.append(ColumnSpan(first: span.first, last: column - 1, width: span.width,
                                         styleIndex: span.styleIndex, hidden: span.hidden))
            }
            result.append(ColumnSpan(first: column, last: column, width: span.width,
                                     styleIndex: span.styleIndex, hidden: span.hidden))
            if span.last > column {
                result.append(ColumnSpan(first: column + 1, last: span.last, width: span.width,
                                         styleIndex: span.styleIndex, hidden: span.hidden))
            }
        }
        columns = result.sorted { $0.first < $1.first }
    }

    public func height(ofRow row: Int) -> Double {
        rows[row]?.height ?? defaultRowHeight
    }

    public mutating func setHeight(_ height: Double, forRow row: Int) {
        rows[row, default: Row()].height = height
    }

    public func mergeContaining(_ address: CellAddress) -> CellRange? {
        merges.first { $0.contains(address) }
    }
}
