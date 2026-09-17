import Foundation

/// Rewrites the A1 references inside a formula.
///
/// Used when a formula is copied to another cell, when rows or columns are
/// inserted or deleted, and to expand the shared formulas Excel writes as a
/// single master expression plus offsets.
public enum FormulaTranslator {
    /// Offsets every relative reference by the given deltas. Absolute parts
    /// (`$A$1`) stay put, which is the whole point of the `$`.
    public static func shift(_ formula: String, rowDelta: Int, columnDelta: Int) -> String {
        transform(formula) { reference in
            var result = reference
            if !reference.columnIsAbsolute { result.column += columnDelta }
            if !reference.rowIsAbsolute { result.row += rowDelta }
            return result
        }
    }

    /// Rewrites references for a row or column insertion or deletion, moving
    /// absolute references too: they name a cell that has itself moved.
    public static func adjust(
        _ formula: String,
        insertingRows range: ClosedRange<Int>? = nil,
        insertingColumns columnRange: ClosedRange<Int>? = nil,
        deletingRows deletedRows: ClosedRange<Int>? = nil,
        deletingColumns deletedColumns: ClosedRange<Int>? = nil
    ) -> String {
        transform(formula, adjustment(
            insertingRows: range, insertingColumns: columnRange,
            deletingRows: deletedRows, deletingColumns: deletedColumns
        ))
    }

    /// The per-reference move behind `adjust`, so a caller can apply it to only
    /// some of a formula's references.
    static func adjustment(
        insertingRows range: ClosedRange<Int>? = nil,
        insertingColumns columnRange: ClosedRange<Int>? = nil,
        deletingRows deletedRows: ClosedRange<Int>? = nil,
        deletingColumns deletedColumns: ClosedRange<Int>? = nil
    ) -> (Reference) -> Reference {
        { reference in
            var result = reference
            if let range, result.row >= range.lowerBound {
                result.row += range.count
            }
            if let columnRange, result.column >= columnRange.lowerBound {
                result.column += columnRange.count
            }
            if let deletedRows {
                // Row 0 is impossible, and renders as #REF!.
                if deletedRows.contains(result.row) { result.row = 0 }
                else if result.row > deletedRows.upperBound { result.row -= deletedRows.count }
            }
            if let deletedColumns {
                if deletedColumns.contains(result.column) { result.column = 0 }
                else if result.column > deletedColumns.upperBound { result.column -= deletedColumns.count }
            }
            return result
        }
    }

    /// A parsed A1 reference with its `$` markers remembered.
    public struct Reference {
        public var row: Int
        public var column: Int
        public var rowIsAbsolute: Bool
        public var columnIsAbsolute: Bool

        var text: String {
            guard row > 0, column > 0, row <= 1_048_576, column <= 16_384 else { return "#REF!" }
            return (columnIsAbsolute ? "$" : "") + CellAddress.columnName(column)
                + (rowIsAbsolute ? "$" : "") + String(row)
        }
    }

    static func transform(_ formula: String, _ body: (Reference) -> Reference) -> String {
        transform(formula) { reference, _ in body(reference) }
    }

    /// The variant that also reports which sheet a reference names, so a caller
    /// can rewrite only the references pointing at one sheet. `nil` means the
    /// reference is unqualified and belongs to the formula's own sheet.
    static func transform(_ formula: String, _ body: (Reference, String?) -> Reference) -> String {
        let characters = Array(formula)
        var output = ""
        output.reserveCapacity(characters.count)
        var index = 0

        while index < characters.count {
            let character = characters[index]

            if character == "\"" {
                index = copyQuoted(characters, from: index, quote: "\"", into: &output)
                continue
            }
            if character == "'" {
                index = copyQuoted(characters, from: index, quote: "'", into: &output)
                continue
            }
            if character == "$" || character.isLetter,
               isReferenceStart(characters, at: index),
               let match = matchReference(characters, at: index) {
                output += body(match.reference, sheetQualifier(characters, before: index)).text
                index = match.end
                continue
            }

            output.append(character)
            index += 1
        }
        return output
    }

    /// The sheet name in `Data!A1` or `'Two Words'!A1`, read backwards from the
    /// reference. Nil when the reference stands alone.
    private static func sheetQualifier(_ characters: [Character], before index: Int) -> String? {
        guard index > 0, characters[index - 1] == "!" else { return nil }
        var cursor = index - 2
        guard cursor >= 0 else { return nil }

        if characters[cursor] == "'" {
            cursor -= 1
            var name = ""
            while cursor >= 0, characters[cursor] != "'" {
                name.insert(characters[cursor], at: name.startIndex)
                cursor -= 1
            }
            return name
        }

        var name = ""
        while cursor >= 0, characters[cursor].isLetter || characters[cursor].isNumber
            || characters[cursor] == "_" || characters[cursor] == "." {
            name.insert(characters[cursor], at: name.startIndex)
            cursor -= 1
        }
        return name.isEmpty ? nil : name
    }

    private static func copyQuoted(_ characters: [Character], from start: Int, quote: Character,
                                   into output: inout String) -> Int {
        var index = start
        output.append(characters[index])
        index += 1
        while index < characters.count {
            output.append(characters[index])
            if characters[index] == quote {
                index += 1
                // A doubled quote is an escaped quote, not the end of the literal.
                if index < characters.count, characters[index] == quote { continue }
                return index
            }
            index += 1
        }
        return index
    }

    /// A reference cannot continue an identifier: `LOG10` and `Sheet1` are not
    /// cell references, but the `A1` in `Sheet1!A1` is.
    private static func isReferenceStart(_ characters: [Character], at index: Int) -> Bool {
        guard index > 0 else { return true }
        let previous = characters[index - 1]
        return !(previous.isLetter || previous.isNumber || previous == "_" || previous == "." || previous == "$")
    }

    private static func matchReference(_ characters: [Character], at start: Int)
        -> (reference: Reference, end: Int)? {
        var index = start
        let columnIsAbsolute = characters[index] == "$"
        if columnIsAbsolute { index += 1 }

        var letters = ""
        while index < characters.count, characters[index].isLetter, letters.count < 3 {
            letters.append(characters[index])
            index += 1
        }
        guard !letters.isEmpty else { return nil }

        let rowIsAbsolute = index < characters.count && characters[index] == "$"
        if rowIsAbsolute { index += 1 }

        var digits = ""
        while index < characters.count, characters[index].isNumber, digits.count < 7 {
            digits.append(characters[index])
            index += 1
        }
        guard !digits.isEmpty else { return nil }

        // `SUM(` and `A1B` are not references.
        if index < characters.count {
            let next = characters[index]
            if next == "(" || next.isLetter || next.isNumber || next == "_" { return nil }
        }
        guard let column = CellAddress.columnIndex(letters), let row = Int(digits), row > 0 else { return nil }

        return (Reference(row: row, column: column,
                          rowIsAbsolute: rowIsAbsolute, columnIsAbsolute: columnIsAbsolute), index)
    }
}
