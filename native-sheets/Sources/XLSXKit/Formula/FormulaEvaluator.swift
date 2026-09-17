import Foundation

/// What an evaluation can read: cell values by sheet and address.
public protocol FormulaWorkbook {
    func sheetIndex(named name: String) -> Int?
    func value(sheetIndex: Int, address: CellAddress) -> FormulaValue
    var sheetCount: Int { get }
}

/// Evaluates a parsed formula against a workbook.
public struct FormulaEvaluator {
    let workbook: any FormulaWorkbook
    /// The sheet an unqualified reference belongs to.
    let sheetIndex: Int
    /// The cell being evaluated, for ROW() and COLUMN().
    let address: CellAddress

    public init(workbook: any FormulaWorkbook, sheetIndex: Int, address: CellAddress) {
        self.workbook = workbook
        self.sheetIndex = sheetIndex
        self.address = address
    }

    public func evaluate(_ node: FormulaNode) -> FormulaValue {
        switch argument(for: node) {
        case .value(let value):
            return value
        case .reference(let sheet, let range):
            // A reference used where a single value is wanted collapses to its
            // top-left cell.
            return workbook.value(sheetIndex: sheet, address: range.start)
        }
    }

    /// A formula's own result is never blank: `=Z99` against an empty cell
    /// shows 0. Blanks stay blank inside an evaluation, where they have to
    /// compare equal to both 0 and "".
    public func result(of node: FormulaNode) -> FormulaValue {
        let value = evaluate(node)
        return value.isBlank ? .number(0) : value
    }

    func argument(for node: FormulaNode) -> FormulaArgument {
        switch node {
        case .literal(let value):
            return .value(value)

        case .unresolvedName:
            return .value(.error(.name))

        case .reference(let reference):
            guard let sheet = resolve(reference) else { return .value(.error(.reference)) }
            return .reference(sheetIndex: sheet, range: reference.range)

        case .unary(let symbol, let operand):
            return .value(applyUnary(symbol, evaluate(operand)))

        case .binary(let symbol, let left, let right):
            return .value(applyBinary(symbol, evaluate(left), evaluate(right)))

        case .call(let name, let arguments):
            return .value(FormulaFunctions.call(name, arguments, in: self))
        }
    }

    func resolve(_ reference: SheetReference) -> Int? {
        guard let name = reference.sheetName else { return sheetIndex }
        return workbook.sheetIndex(named: name)
    }

    // MARK: - Operators

    private func applyUnary(_ symbol: String, _ value: FormulaValue) -> FormulaValue {
        if let error = value.errorValue { return .error(error) }
        switch value.asNumber() {
        case .failure(let error):
            return .error(error)
        case .success(let number):
            switch symbol {
            case "-": return .number(-number)
            case "+": return .number(number)
            case "%": return .number(number / 100)
            default: return .error(.value)
            }
        }
    }

    private func applyBinary(_ symbol: String, _ left: FormulaValue, _ right: FormulaValue) -> FormulaValue {
        if let error = left.errorValue { return .error(error) }
        if let error = right.errorValue { return .error(error) }

        if symbol == "&" {
            switch (left.asText(), right.asText()) {
            case (.success(let a), .success(let b)): return .text(a + b)
            default: return .error(.value)
            }
        }

        if ["=", "<>", "<", ">", "<=", ">="].contains(symbol) {
            return .boolean(compare(left, right, symbol))
        }

        guard case .success(let a) = left.asNumber(), case .success(let b) = right.asNumber() else {
            return .error(.value)
        }
        switch symbol {
        case "+": return .number(a + b)
        case "-": return .number(a - b)
        case "*": return .number(a * b)
        case "/": return b == 0 ? .error(.divideByZero) : .number(a / b)
        case "^":
            let result = pow(a, b)
            return result.isNaN || result.isInfinite ? .error(.number) : .number(result)
        default: return .error(.value)
        }
    }

    /// Comparison follows the spreadsheet's ordering: numbers before text
    /// before booleans, with text compared case-insensitively.
    private func compare(_ left: FormulaValue, _ right: FormulaValue, _ symbol: String) -> Bool {
        let ordering: ComparisonResult
        switch (left, right) {
        case (.text(let a), .text(let b)):
            ordering = a.caseInsensitiveCompare(b)
        case (.boolean(let a), .boolean(let b)):
            ordering = a == b ? .orderedSame : (a ? .orderedDescending : .orderedAscending)
        case (.text, _) where !right.isBlank:
            ordering = .orderedDescending
        case (_, .text) where !left.isBlank:
            ordering = .orderedAscending
        default:
            let a = (try? left.asNumber().get()) ?? 0
            let b = (try? right.asNumber().get()) ?? 0
            ordering = a == b ? .orderedSame : (a < b ? .orderedAscending : .orderedDescending)
        }

        switch symbol {
        case "=": return ordering == .orderedSame
        case "<>": return ordering != .orderedSame
        case "<": return ordering == .orderedAscending
        case ">": return ordering == .orderedDescending
        case "<=": return ordering != .orderedDescending
        default: return ordering != .orderedAscending
        }
    }

    // MARK: - Argument helpers

    /// Walks an argument's values, whether it is a single value or a range.
    func forEachValue(_ argument: FormulaArgument, _ body: (FormulaValue) -> Void) {
        switch argument {
        case .value(let value):
            body(value)
        case .reference(let sheet, let range):
            for row in range.rows {
                for column in range.columns {
                    body(workbook.value(sheetIndex: sheet, address: CellAddress(row: row, column: column)))
                }
            }
        }
    }

    func values(of argument: FormulaArgument) -> [FormulaValue] {
        var collected: [FormulaValue] = []
        forEachValue(argument) { collected.append($0) }
        return collected
    }

    func value(of argument: FormulaArgument) -> FormulaValue {
        switch argument {
        case .value(let value): return value
        case .reference(let sheet, let range):
            return workbook.value(sheetIndex: sheet, address: range.start)
        }
    }

    func value(sheetIndex: Int, row: Int, column: Int) -> FormulaValue {
        workbook.value(sheetIndex: sheetIndex, address: CellAddress(row: row, column: column))
    }
}
