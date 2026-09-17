import Foundation

/// Something worth telling the user about after a recalculation.
public struct RecalculationIssue: Sendable {
    public enum Kind: Sendable {
        case circularReference
        case parseFailure
    }

    public let kind: Kind
    public let sheetName: String
    public let address: CellAddress

    public var message: String {
        switch kind {
        case .circularReference: return "Circular reference at \(sheetName)!\(address.a1)"
        case .parseFailure: return "\(sheetName)!\(address.a1) is not a formula this editor understands"
        }
    }
}

/// Recomputes formula cells and writes the results back into the workbook.
///
/// Formulas are evaluated in dependency order, so a chain of references settles
/// in one pass rather than converging over several.
public struct Recalculator {
    private struct FormulaCell {
        let sheetIndex: Int
        let address: CellAddress
        let node: FormulaNode?
        /// Ranges this formula reads, resolved to sheet indexes.
        let precedents: [(sheetIndex: Int, range: CellRange)]
    }

    private let cells: [FormulaCell]
    private let workbook: Workbook

    public init(_ workbook: Workbook) {
        self.workbook = workbook
        var cells: [FormulaCell] = []
        for (sheetIndex, sheet) in workbook.sheets.enumerated() {
            for (rowIndex, row) in sheet.rows {
                for (column, cell) in row.cells {
                    guard let formula = cell.formula else { continue }
                    let address = CellAddress(row: rowIndex, column: column)
                    let node = try? FormulaParser.parse(formula)
                    let precedents = (node?.references ?? []).compactMap { reference -> (Int, CellRange)? in
                        let target = reference.sheetName.flatMap { workbook.index(ofSheet: $0) } ?? sheetIndex
                        guard workbook.sheets.indices.contains(target) else { return nil }
                        return (target, reference.range)
                    }
                    cells.append(FormulaCell(sheetIndex: sheetIndex, address: address,
                                             node: node, precedents: precedents))
                }
            }
        }
        self.cells = cells
    }

    /// Recomputes every formula in the workbook.
    @discardableResult
    public static func recalculate(_ workbook: inout Workbook) -> [RecalculationIssue] {
        Recalculator(workbook).apply(to: &workbook)
    }

    /// Recomputes only the formulas that depend, directly or not, on cells that
    /// have just changed.
    @discardableResult
    public static func recalculate(
        _ workbook: inout Workbook,
        changedCells: [(sheetIndex: Int, address: CellAddress)]
    ) -> [RecalculationIssue] {
        Recalculator(workbook).apply(to: &workbook, changedCells: changedCells)
    }

    @discardableResult
    public func apply(
        to workbook: inout Workbook,
        changedCells: [(sheetIndex: Int, address: CellAddress)]? = nil
    ) -> [RecalculationIssue] {
        guard !cells.isEmpty else { return [] }

        var issues: [RecalculationIssue] = []
        var (order, circular) = evaluationOrder()
        if let changedCells {
            let affected = formulas(affectedBy: changedCells)
            order = order.filter { affected.contains($0) }
            circular = circular.filter { affected.contains($0) }
        }
        let context = MutableWorkbookContext(workbook)

        for index in order {
            let cell = cells[index]
            guard let node = cell.node else {
                issues.append(RecalculationIssue(kind: .parseFailure,
                                                 sheetName: workbook.sheets[cell.sheetIndex].name,
                                                 address: cell.address))
                context.set(.error(.name), sheetIndex: cell.sheetIndex, address: cell.address)
                continue
            }
            let evaluator = FormulaEvaluator(workbook: context, sheetIndex: cell.sheetIndex, address: cell.address)
            context.set(evaluator.result(of: node), sheetIndex: cell.sheetIndex, address: cell.address)
        }

        for index in circular {
            let cell = cells[index]
            issues.append(RecalculationIssue(kind: .circularReference,
                                             sheetName: workbook.sheets[cell.sheetIndex].name,
                                             address: cell.address))
            context.set(.error(.reference), sheetIndex: cell.sheetIndex, address: cell.address)
        }

        context.write(into: &workbook)
        return issues
    }

    /// The formulas reading any of `changedCells`, plus everything downstream
    /// of those.
    private func formulas(affectedBy changedCells: [(sheetIndex: Int, address: CellAddress)]) -> Set<Int> {
        var affected = Set<Int>()
        var queue: [Int] = []

        for (index, cell) in cells.enumerated() {
            let reads = changedCells.contains { change in
                cell.precedents.contains {
                    $0.sheetIndex == change.sheetIndex && $0.range.contains(change.address)
                }
            }
            // A changed cell that is itself a formula has to be recomputed too,
            // since its own definition may be what changed.
            let isItself = changedCells.contains {
                $0.sheetIndex == cell.sheetIndex && $0.address == cell.address
            }
            if reads || isItself, affected.insert(index).inserted {
                queue.append(index)
            }
        }

        var head = 0
        while head < queue.count {
            let index = queue[head]
            head += 1
            let source = cells[index]
            for (candidate, cell) in cells.enumerated() where !affected.contains(candidate) {
                let reads = cell.precedents.contains {
                    $0.sheetIndex == source.sheetIndex && $0.range.contains(source.address)
                }
                if reads, affected.insert(candidate).inserted { queue.append(candidate) }
            }
        }
        return affected
    }

    /// Kahn's algorithm over the formula cells. Whatever is left when no node
    /// has an in-degree of zero is part of a cycle.
    private func evaluationOrder() -> (order: [Int], circular: [Int]) {
        let locator = FormulaLocator(cells.enumerated().map {
            (index: $0.offset, sheetIndex: $0.element.sheetIndex, address: $0.element.address)
        })

        var dependents: [[Int]] = Array(repeating: [], count: cells.count)
        var inDegree = [Int](repeating: 0, count: cells.count)

        for (index, cell) in cells.enumerated() {
            var seen = Set<Int>()
            for precedent in cell.precedents {
                // A cell inside its own precedent range keeps its edge, which
                // is what makes a self-reference show up as a cycle.
                for source in locator.indexes(inSheet: precedent.sheetIndex, range: precedent.range)
                where !seen.contains(source) {
                    seen.insert(source)
                    dependents[source].append(index)
                    inDegree[index] += 1
                }
            }
        }

        var queue = (0..<cells.count).filter { inDegree[$0] == 0 }
        var order: [Int] = []
        order.reserveCapacity(cells.count)
        var head = 0

        while head < queue.count {
            let index = queue[head]
            head += 1
            order.append(index)
            for dependent in dependents[index] {
                inDegree[dependent] -= 1
                if inDegree[dependent] == 0 { queue.append(dependent) }
            }
        }

        let resolved = Set(order)
        return (order, (0..<cells.count).filter { !resolved.contains($0) })
    }
}

/// Finds which formula cells fall inside a range, without walking the range.
private struct FormulaLocator {
    /// Per sheet, formula cells sorted by row then column.
    private var bySheet: [Int: [(row: Int, column: Int, index: Int)]] = [:]

    init(_ entries: [(index: Int, sheetIndex: Int, address: CellAddress)]) {
        for entry in entries {
            bySheet[entry.sheetIndex, default: []]
                .append((entry.address.row, entry.address.column, entry.index))
        }
        for key in bySheet.keys {
            bySheet[key]?.sort { $0.row == $1.row ? $0.column < $1.column : $0.row < $1.row }
        }
    }

    func indexes(inSheet sheetIndex: Int, range: CellRange) -> [Int] {
        guard let entries = bySheet[sheetIndex] else { return [] }
        var position = lowerBound(entries, row: range.start.row)
        var result: [Int] = []
        while position < entries.count, entries[position].row <= range.end.row {
            let entry = entries[position]
            if entry.column >= range.start.column, entry.column <= range.end.column {
                result.append(entry.index)
            }
            position += 1
        }
        return result
    }

    private func lowerBound(_ entries: [(row: Int, column: Int, index: Int)], row: Int) -> Int {
        var low = 0
        var high = entries.count
        while low < high {
            let middle = (low + high) / 2
            if entries[middle].row < row { low = middle + 1 } else { high = middle }
        }
        return low
    }
}

/// A workbook snapshot that evaluation reads from and writes results into.
///
/// Range functions read millions of cells during a full recalculation, so
/// values live in a dense grid per sheet rather than a dictionary: one array
/// index instead of hashing an address.
private final class MutableWorkbookContext: FormulaWorkbook {
    private var sheets: [[CellAddress: FormulaValue]]
    private var changed: [[CellAddress: FormulaValue]]
    private let namesToIndexes: [String: Int]

    init(_ workbook: Workbook) {
        sheets = workbook.sheets.map { sheet in
            var flat: [CellAddress: FormulaValue] = [:]
            for (rowIndex, row) in sheet.rows {
                for (column, cell) in row.cells {
                    flat[CellAddress(row: rowIndex, column: column)] = FormulaValue(cell.value)
                }
            }
            return flat
        }
        changed = Array(repeating: [:], count: workbook.sheets.count)

        var names: [String: Int] = [:]
        for (index, sheet) in workbook.sheets.enumerated() {
            names[sheet.name.lowercased()] = index
        }
        namesToIndexes = names
    }

    var sheetCount: Int { sheets.count }

    func sheetIndex(named name: String) -> Int? {
        namesToIndexes[name.lowercased()]
    }

    func value(sheetIndex: Int, address: CellAddress) -> FormulaValue {
        guard sheets.indices.contains(sheetIndex) else { return .error(.reference) }
        return sheets[sheetIndex][address] ?? .empty
    }

    func set(_ value: FormulaValue, sheetIndex: Int, address: CellAddress) {
        guard sheets.indices.contains(sheetIndex) else { return }
        sheets[sheetIndex][address] = value
        changed[sheetIndex][address] = value
    }

    func write(into workbook: inout Workbook) {
        for (sheetIndex, updates) in changed.enumerated() {
            guard workbook.sheets.indices.contains(sheetIndex) else { continue }
            for (address, value) in updates {
                workbook.sheets[sheetIndex][address].value = value.cellValue
            }
        }
    }
}

extension Workbook {
    /// Evaluates a formula against the workbook without storing anything.
    public func evaluate(_ formula: String, on sheetIndex: Int, at address: CellAddress) -> CellValue {
        guard let node = try? FormulaParser.parse(formula) else { return .error(FormulaError.name.rawValue) }
        let context = ReadOnlyWorkbookContext(self)
        return FormulaEvaluator(workbook: context, sheetIndex: sheetIndex, address: address)
            .result(of: node).cellValue
    }
}

private struct ReadOnlyWorkbookContext: FormulaWorkbook {
    private let workbook: Workbook

    init(_ workbook: Workbook) {
        self.workbook = workbook
    }

    var sheetCount: Int { workbook.sheets.count }

    func sheetIndex(named name: String) -> Int? { workbook.index(ofSheet: name) }

    func value(sheetIndex: Int, address: CellAddress) -> FormulaValue {
        guard workbook.sheets.indices.contains(sheetIndex) else { return .error(.reference) }
        return FormulaValue(workbook.sheets[sheetIndex][address].value)
    }
}
