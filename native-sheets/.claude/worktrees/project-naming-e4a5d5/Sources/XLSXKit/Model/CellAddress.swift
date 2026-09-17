import Foundation

/// A cell position, 1-based in both axes to match A1 notation and the file
/// format.
public struct CellAddress: Hashable, Comparable, Sendable {
    public var row: Int
    public var column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }

    public init?(a1: String) {
        var column = 0
        var row = 0
        var sawDigit = false
        for character in a1.uppercased().unicodeScalars {
            switch character {
            case "$":
                continue
            case "A"..."Z":
                guard !sawDigit else { return nil }
                column = column * 26 + Int(character.value - 64)
            case "0"..."9":
                sawDigit = true
                row = row * 10 + Int(character.value - 48)
            default:
                return nil
            }
        }
        guard column > 0, row > 0 else { return nil }
        self.row = row
        self.column = column
    }

    public var a1: String { "\(CellAddress.columnName(column))\(row)" }

    /// 1 → A, 26 → Z, 27 → AA.
    public static func columnName(_ column: Int) -> String {
        var remaining = column
        var name = ""
        while remaining > 0 {
            let digit = (remaining - 1) % 26
            name = String(UnicodeScalar(UInt8(65 + digit))) + name
            remaining = (remaining - 1) / 26
        }
        return name
    }

    public static func columnIndex(_ name: String) -> Int? {
        var value = 0
        for character in name.uppercased().unicodeScalars {
            guard ("A"..."Z").contains(character) else { return nil }
            value = value * 26 + Int(character.value - 64)
        }
        return value > 0 ? value : nil
    }

    public static func < (lhs: CellAddress, rhs: CellAddress) -> Bool {
        lhs.row == rhs.row ? lhs.column < rhs.column : lhs.row < rhs.row
    }
}

/// A rectangular block of cells, inclusive on both corners.
public struct CellRange: Hashable, Sendable {
    public var start: CellAddress
    public var end: CellAddress

    public init(start: CellAddress, end: CellAddress) {
        self.start = CellAddress(row: min(start.row, end.row), column: min(start.column, end.column))
        self.end = CellAddress(row: max(start.row, end.row), column: max(start.column, end.column))
    }

    public init(_ address: CellAddress) {
        self.init(start: address, end: address)
    }

    public init?(a1: String) {
        let parts = a1.split(separator: ":", maxSplits: 1)
        guard let first = parts.first, let start = CellAddress(a1: String(first)) else { return nil }
        if parts.count == 1 {
            self.init(start: start, end: start)
        } else {
            guard let end = CellAddress(a1: String(parts[1])) else { return nil }
            self.init(start: start, end: end)
        }
    }

    public var a1: String { start == end ? start.a1 : "\(start.a1):\(end.a1)" }
    public var rowCount: Int { end.row - start.row + 1 }
    public var columnCount: Int { end.column - start.column + 1 }
    public var rows: ClosedRange<Int> { start.row...end.row }
    public var columns: ClosedRange<Int> { start.column...end.column }

    public func contains(_ address: CellAddress) -> Bool {
        rows.contains(address.row) && columns.contains(address.column)
    }

    public func overlaps(_ other: CellRange) -> Bool {
        rows.overlaps(other.rows) && columns.overlaps(other.columns)
    }

    public var addresses: [CellAddress] {
        rows.flatMap { row in columns.map { CellAddress(row: row, column: $0) } }
    }
}
