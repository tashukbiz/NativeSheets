import Foundation

/// The error values a formula can produce, spelled as the file format spells
/// them.
public enum FormulaError: String, Error, Sendable, Hashable {
    case null = "#NULL!"
    case divideByZero = "#DIV/0!"
    case value = "#VALUE!"
    case reference = "#REF!"
    case name = "#NAME?"
    case number = "#NUM!"
    case notAvailable = "#N/A"
}

/// A value flowing through an evaluation.
public enum FormulaValue: Sendable, Equatable {
    case empty
    case number(Double)
    case text(String)
    case boolean(Bool)
    case error(FormulaError)

    public init(_ cellValue: CellValue) {
        switch cellValue {
        case .empty: self = .empty
        case .number(let number): self = .number(number)
        case .text(let text): self = .text(text)
        case .boolean(let flag): self = .boolean(flag)
        case .error(let code): self = .error(FormulaError(rawValue: code) ?? .value)
        }
    }

    public var cellValue: CellValue {
        switch self {
        case .empty: return .empty
        case .number(let number): return .number(number)
        case .text(let text): return .text(text)
        case .boolean(let flag): return .boolean(flag)
        case .error(let error): return .error(error.rawValue)
        }
    }

    var errorValue: FormulaError? {
        if case .error(let error) = self { return error }
        return nil
    }

    /// Numeric coercion, following the spreadsheet's rules: blanks and `FALSE`
    /// are zero, and text converts only when it looks like a number.
    func asNumber() -> Result<Double, FormulaError> {
        switch self {
        case .empty: return .success(0)
        case .number(let number): return .success(number)
        case .boolean(let flag): return .success(flag ? 1 : 0)
        case .error(let error): return .failure(error)
        case .text(let text):
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return .success(0) }
            guard let number = Double(trimmed) else { return .failure(.value) }
            return .success(number)
        }
    }

    func asText() -> Result<String, FormulaError> {
        switch self {
        case .empty: return .success("")
        case .text(let text): return .success(text)
        case .boolean(let flag): return .success(flag ? "TRUE" : "FALSE")
        case .number(let number): return .success(NumberFormat.general(number))
        case .error(let error): return .failure(error)
        }
    }

    func asBoolean() -> Result<Bool, FormulaError> {
        switch self {
        case .empty: return .success(false)
        case .boolean(let flag): return .success(flag)
        case .number(let number): return .success(number != 0)
        case .error(let error): return .failure(error)
        case .text(let text):
            switch text.uppercased() {
            case "TRUE": return .success(true)
            case "FALSE": return .success(false)
            default: return .failure(.value)
            }
        }
    }

    var isBlank: Bool {
        if case .empty = self { return true }
        return false
    }
}

/// Where a reference points. A missing sheet name means the formula's own
/// sheet.
public struct SheetReference: Hashable, Sendable {
    public var sheetName: String?
    public var range: CellRange

    public init(sheetName: String?, range: CellRange) {
        self.sheetName = sheetName
        self.range = range
    }
}

/// An argument as the evaluator hands it to a function: either a computed
/// value, or a reference left unmaterialized so that range functions can walk
/// it without building an array.
public enum FormulaArgument: Sendable {
    case value(FormulaValue)
    case reference(sheetIndex: Int, range: CellRange)
}
