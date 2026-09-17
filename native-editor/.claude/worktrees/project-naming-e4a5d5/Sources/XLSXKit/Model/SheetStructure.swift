import Foundation

extension Workbook {
    /// Inserts blank rows above `row`, pushing everything below it down.
    ///
    /// Formulas anywhere in the workbook that point at the affected sheet are
    /// rewritten, so a reference keeps naming the same cell after it moves.
    public mutating func insertRows(at row: Int, count: Int = 1, inSheet sheetIndex: Int) {
        guard count > 0, sheets.indices.contains(sheetIndex) else { return }
        shiftRows(in: sheetIndex, from: row, by: count)
        adjustFormulas(targeting: sheetIndex,
                       FormulaTranslator.adjustment(insertingRows: row...(row + count - 1)))
    }

    /// Deletes rows, pulling everything below them up. References into the
    /// deleted rows become `#REF!`, as they must.
    public mutating func removeRows(at row: Int, count: Int = 1, inSheet sheetIndex: Int) {
        guard count > 0, sheets.indices.contains(sheetIndex) else { return }
        for index in row..<(row + count) { sheets[sheetIndex].rows.removeValue(forKey: index) }
        shiftRows(in: sheetIndex, from: row + count, by: -count)
        adjustFormulas(targeting: sheetIndex,
                       FormulaTranslator.adjustment(deletingRows: row...(row + count - 1)))
    }

    public mutating func insertColumns(at column: Int, count: Int = 1, inSheet sheetIndex: Int) {
        guard count > 0, sheets.indices.contains(sheetIndex) else { return }
        shiftColumns(in: sheetIndex, from: column, by: count)
        adjustFormulas(targeting: sheetIndex,
                       FormulaTranslator.adjustment(insertingColumns: column...(column + count - 1)))
    }

    public mutating func removeColumns(at column: Int, count: Int = 1, inSheet sheetIndex: Int) {
        guard count > 0, sheets.indices.contains(sheetIndex) else { return }
        for key in sheets[sheetIndex].rows.keys {
            for index in column..<(column + count) {
                sheets[sheetIndex].rows[key]?.cells.removeValue(forKey: index)
            }
        }
        shiftColumns(in: sheetIndex, from: column + count, by: -count)
        adjustFormulas(targeting: sheetIndex,
                       FormulaTranslator.adjustment(deletingColumns: column...(column + count - 1)))
    }

    // MARK: - Moving cells

    private mutating func shiftRows(in sheetIndex: Int, from start: Int, by delta: Int) {
        var moved: [Int: Row] = [:]
        for (index, row) in sheets[sheetIndex].rows {
            if index >= start {
                let destination = index + delta
                if destination >= 1 { moved[destination] = row }
            } else {
                moved[index] = row
            }
        }
        sheets[sheetIndex].rows = moved

        sheets[sheetIndex].merges = sheets[sheetIndex].merges.compactMap { merge in
            shift(merge, from: start, by: delta, vertical: true)
        }
    }

    private mutating func shiftColumns(in sheetIndex: Int, from start: Int, by delta: Int) {
        for key in sheets[sheetIndex].rows.keys {
            guard let cells = sheets[sheetIndex].rows[key]?.cells else { continue }
            var moved: [Int: Cell] = [:]
            for (column, cell) in cells {
                if column >= start {
                    let destination = column + delta
                    if destination >= 1 { moved[destination] = cell }
                } else {
                    moved[column] = cell
                }
            }
            sheets[sheetIndex].rows[key]?.cells = moved
        }

        sheets[sheetIndex].columns = sheets[sheetIndex].columns.compactMap { span in
            var moved = span
            if span.first >= start { moved.first += delta }
            if span.last >= start { moved.last += delta }
            guard moved.last >= 1, moved.first >= 1, moved.first <= moved.last else { return nil }
            return moved
        }

        sheets[sheetIndex].merges = sheets[sheetIndex].merges.compactMap { merge in
            shift(merge, from: start, by: delta, vertical: false)
        }
    }

    private func shift(_ merge: CellRange, from start: Int, by delta: Int, vertical: Bool) -> CellRange? {
        var startValue = vertical ? merge.start.row : merge.start.column
        var endValue = vertical ? merge.end.row : merge.end.column
        if startValue >= start { startValue += delta }
        if endValue >= start { endValue += delta }
        guard startValue >= 1, endValue >= startValue else { return nil }

        return vertical
            ? CellRange(start: CellAddress(row: startValue, column: merge.start.column),
                        end: CellAddress(row: endValue, column: merge.end.column))
            : CellRange(start: CellAddress(row: merge.start.row, column: startValue),
                        end: CellAddress(row: merge.end.row, column: endValue))
    }

    // MARK: - Formulas

    /// Rewrites every formula reference that points at `sheetIndex`, wherever
    /// in the workbook the formula lives. References to other sheets are left
    /// exactly as they are.
    private mutating func adjustFormulas(targeting sheetIndex: Int,
                                         _ move: @escaping (FormulaTranslator.Reference) -> FormulaTranslator.Reference) {
        let targetName = sheets[sheetIndex].name

        for index in sheets.indices {
            let isOwnSheet = index == sheetIndex
            for rowKey in sheets[index].rows.keys {
                guard let cells = sheets[index].rows[rowKey]?.cells else { continue }
                for (column, cell) in cells {
                    guard let formula = cell.formula else { continue }
                    let rewritten = FormulaTranslator.transform(formula) { reference, qualifier in
                        let targeted = qualifier.map {
                            $0.caseInsensitiveCompare(targetName) == .orderedSame
                        } ?? isOwnSheet
                        return targeted ? move(reference) : reference
                    }
                    guard rewritten != formula else { continue }
                    sheets[index].rows[rowKey]?.cells[column]?.formula = rewritten
                }
            }
        }
    }
}
