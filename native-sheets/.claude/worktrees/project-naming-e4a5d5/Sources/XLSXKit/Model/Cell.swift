import Foundation

/// A stored cell value. Dates are numbers carrying a date number format, which
/// is how the file format represents them.
public enum CellValue: Hashable, Sendable {
    case empty
    case number(Double)
    case text(String)
    case boolean(Bool)
    case error(String)

    public var isEmpty: Bool {
        if case .empty = self { return true }
        if case .text(let value) = self { return value.isEmpty }
        return false
    }

    public var numberValue: Double? {
        switch self {
        case .number(let value): return value
        case .boolean(let value): return value ? 1 : 0
        default: return nil
        }
    }

    public var textValue: String? {
        if case .text(let value) = self { return value }
        return nil
    }
}

/// One cell: what it holds, how it was computed, and how it is painted.
///
/// `value` is the cached result for a formula cell, mirroring the `<v>` element
/// the file keeps beside `<f>`.
public struct Cell: Hashable, Sendable {
    public var value: CellValue
    public var formula: String?
    public var styleIndex: Int

    public init(value: CellValue = .empty, formula: String? = nil, styleIndex: Int = 0) {
        self.value = value
        self.formula = formula
        self.styleIndex = styleIndex
    }

    public var isBlank: Bool { value.isEmpty && formula == nil }

    /// True when nothing about the cell is worth storing, style included.
    public var isDefault: Bool { isBlank && styleIndex == 0 }
}

/// A row's own properties. Cells are sparse within the row.
public struct Row: Sendable {
    public var cells: [Int: Cell] = [:]
    public var height: Double?
    public var styleIndex: Int?
    public var hidden: Bool = false

    public init() {}

    public var isDefault: Bool {
        cells.values.allSatisfy(\.isDefault) && height == nil && styleIndex == nil && !hidden
    }
}
