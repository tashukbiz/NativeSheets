import Foundation

extension FormulaFunctions {
    static func applyTextAndLookup(_ name: String, _ arguments: [FormulaArgument],
                                   _ evaluator: FormulaEvaluator) -> FormulaValue {
        func text(_ index: Int) -> Result<String, FormulaError> {
            guard index < arguments.count else { return .failure(.value) }
            return evaluator.value(of: arguments[index]).asText()
        }
        func number(_ index: Int) -> Result<Double, FormulaError> {
            guard index < arguments.count else { return .failure(.value) }
            return evaluator.value(of: arguments[index]).asNumber()
        }

        switch name {
        // MARK: Text
        case "LEN":
            return map(text(0)) { .number(Double($0.count)) }
        case "LOWER":
            return map(text(0)) { .text($0.lowercased()) }
        case "UPPER":
            return map(text(0)) { .text($0.uppercased()) }
        case "PROPER":
            return map(text(0)) { .text($0.capitalized) }
        case "TRIM":
            return map(text(0)) { value in
                // Collapses runs of spaces as well as trimming the ends.
                .text(value.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " "))
            }
        case "LEFT", "RIGHT":
            guard case .success(let source) = text(0) else { return errorOf(text(0)) }
            var count = 1
            if arguments.count >= 2 {
                guard case .success(let value) = number(1) else { return errorOf(number(1)) }
                count = Int(value)
            }
            guard count >= 0 else { return .error(.value) }
            let clamped = min(count, source.count)
            return .text(name == "LEFT" ? String(source.prefix(clamped)) : String(source.suffix(clamped)))
        case "MID":
            guard case .success(let source) = text(0),
                  case .success(let start) = number(1),
                  case .success(let length) = number(2) else { return .error(.value) }
            guard start >= 1, length >= 0 else { return .error(.value) }
            let characters = Array(source)
            let from = min(Int(start) - 1, characters.count)
            let to = min(from + Int(length), characters.count)
            return .text(String(characters[from..<to]))
        case "REPT":
            guard case .success(let source) = text(0), case .success(let times) = number(1) else {
                return .error(.value)
            }
            guard times >= 0 else { return .error(.value) }
            return .text(String(repeating: source, count: Int(times)))
        case "CONCAT", "CONCATENATE":
            var joined = ""
            var failure: FormulaError?
            for argument in arguments {
                evaluator.forEachValue(argument) { value in
                    switch value.asText() {
                    case .success(let part): joined += part
                    case .failure(let error): failure = failure ?? error
                    }
                }
            }
            return failure.map { FormulaValue.error($0) } ?? .text(joined)
        case "TEXTJOIN":
            guard arguments.count >= 3, case .success(let separator) = text(0) else { return .error(.value) }
            let skipEmpty = (try? evaluator.value(of: arguments[1]).asBoolean().get()) ?? true
            var parts: [String] = []
            for argument in arguments.dropFirst(2) {
                evaluator.forEachValue(argument) { value in
                    guard case .success(let part) = value.asText() else { return }
                    if skipEmpty && part.isEmpty { return }
                    parts.append(part)
                }
            }
            return .text(parts.joined(separator: separator))
        case "SUBSTITUTE":
            guard case .success(let source) = text(0),
                  case .success(let old) = text(1),
                  case .success(let new) = text(2) else { return .error(.value) }
            guard !old.isEmpty else { return .text(source) }
            guard arguments.count >= 4 else {
                return .text(source.replacingOccurrences(of: old, with: new))
            }
            guard case .success(let occurrence) = number(3), occurrence >= 1 else { return .error(.value) }
            return .text(replace(source, old, new, occurrence: Int(occurrence)))
        case "REPLACE":
            guard case .success(let source) = text(0),
                  case .success(let start) = number(1),
                  case .success(let length) = number(2),
                  case .success(let replacement) = text(3) else { return .error(.value) }
            var characters = Array(source)
            let from = max(0, min(Int(start) - 1, characters.count))
            let to = max(from, min(from + Int(length), characters.count))
            characters.replaceSubrange(from..<to, with: Array(replacement))
            return .text(String(characters))
        case "FIND", "SEARCH":
            guard case .success(let needle) = text(0), case .success(let haystack) = text(1) else {
                return .error(.value)
            }
            var start = 1
            if arguments.count >= 3 {
                guard case .success(let value) = number(2), value >= 1 else { return .error(.value) }
                start = Int(value)
            }
            let characters = Array(haystack)
            guard start - 1 <= characters.count else { return .error(.value) }
            let scope = String(characters[(start - 1)...])
            // FIND is case-sensitive and literal; SEARCH is neither.
            let range = name == "FIND"
                ? scope.range(of: needle)
                : scope.range(of: needle, options: [.caseInsensitive])
            guard let range else { return .error(.value) }
            return .number(Double(scope.distance(from: scope.startIndex, to: range.lowerBound) + start))
        case "EXACT":
            guard case .success(let a) = text(0), case .success(let b) = text(1) else { return .error(.value) }
            return .boolean(a == b)
        case "CHAR":
            guard case .success(let code) = number(0), let scalar = UnicodeScalar(UInt32(max(0, code))) else {
                return .error(.value)
            }
            return .text(String(Character(scalar)))
        case "CODE":
            guard case .success(let source) = text(0), let first = source.unicodeScalars.first else {
                return .error(.value)
            }
            return .number(Double(first.value))
        case "VALUE":
            guard case .success(let source) = text(0) else { return .error(.value) }
            guard let value = Double(source.trimmingCharacters(in: .whitespaces)) else { return .error(.value) }
            return .number(value)
        case "TEXT":
            guard arguments.count >= 2, case .success(let code) = text(1) else { return .error(.value) }
            let value = evaluator.value(of: arguments[0])
            return .text(NumberFormat.shared(for: code).string(for: value.cellValue).text)

        // MARK: Lookup
        case "ROWS", "COLUMNS":
            guard case .reference(_, let range) = arguments.first else { return .error(.value) }
            return .number(Double(name == "ROWS" ? range.rowCount : range.columnCount))
        case "INDEX": return index(arguments, evaluator)
        case "MATCH": return match(arguments, evaluator)
        case "VLOOKUP": return lookup(arguments, evaluator, vertical: true)
        case "HLOOKUP": return lookup(arguments, evaluator, vertical: false)

        // MARK: Dates
        case "TODAY": return .number(ExcelDate.serial(from: Date()).rounded(.down))
        case "NOW": return .number(ExcelDate.serial(from: Date()))
        case "DATE":
            guard case .success(let year) = number(0),
                  case .success(let month) = number(1),
                  case .success(let day) = number(2) else { return .error(.value) }
            return dateSerial(year: Int(year), month: Int(month), day: Int(day))
        case "YEAR", "MONTH", "DAY", "HOUR", "MINUTE", "SECOND", "WEEKDAY":
            guard case .success(let serial) = number(0), serial >= 0 else { return .error(.number) }
            let parts = ExcelDate.components(from: serial)
            switch name {
            case "YEAR": return .number(Double(parts.year))
            case "MONTH": return .number(Double(parts.month))
            case "DAY": return .number(Double(parts.day))
            case "HOUR": return .number(Double(parts.hour))
            case "MINUTE": return .number(Double(parts.minute))
            case "SECOND": return .number(Double(parts.second))
            default: return .number(Double(parts.weekday))
            }
        case "DAYS":
            guard case .success(let end) = number(0), case .success(let start) = number(1) else {
                return .error(.value)
            }
            return .number((end - start).rounded(.towardZero))
        case "EDATE", "EOMONTH":
            guard case .success(let serial) = number(0), case .success(let offset) = number(1) else {
                return .error(.value)
            }
            return shiftMonths(serial: serial, by: Int(offset), toEndOfMonth: name == "EOMONTH")

        // MARK: Information
        case "ISBLANK": return .boolean(evaluator.value(of: arguments.first ?? .value(.empty)).isBlank)
        case "ISNUMBER":
            if case .number = evaluator.value(of: arguments.first ?? .value(.empty)) { return .boolean(true) }
            return .boolean(false)
        case "ISTEXT":
            if case .text = evaluator.value(of: arguments.first ?? .value(.empty)) { return .boolean(true) }
            return .boolean(false)
        case "ISLOGICAL":
            if case .boolean = evaluator.value(of: arguments.first ?? .value(.empty)) { return .boolean(true) }
            return .boolean(false)
        case "ISERROR":
            return .boolean(evaluator.value(of: arguments.first ?? .value(.empty)).errorValue != nil)
        case "ISERR":
            let error = evaluator.value(of: arguments.first ?? .value(.empty)).errorValue
            return .boolean(error != nil && error != .notAvailable)
        case "ISNA":
            return .boolean(evaluator.value(of: arguments.first ?? .value(.empty)).errorValue == .notAvailable)
        case "NA": return .error(.notAvailable)

        default:
            return .error(.name)
        }
    }

    // MARK: - Helpers

    private static func map(_ result: Result<String, FormulaError>,
                            _ body: (String) -> FormulaValue) -> FormulaValue {
        switch result {
        case .success(let value): return body(value)
        case .failure(let error): return .error(error)
        }
    }

    private static func errorOf<T>(_ result: Result<T, FormulaError>) -> FormulaValue {
        if case .failure(let error) = result { return .error(error) }
        return .error(.value)
    }

    private static func replace(_ source: String, _ old: String, _ new: String, occurrence: Int) -> String {
        var result = source
        var searchStart = result.startIndex
        var seen = 0
        while let range = result.range(of: old, range: searchStart..<result.endIndex) {
            seen += 1
            if seen == occurrence {
                result.replaceSubrange(range, with: new)
                return result
            }
            searchStart = range.upperBound
        }
        return result
    }

    private static func dateSerial(year: Int, month: Int, day: Int) -> FormulaValue {
        var components = DateComponents()
        // Month and day overflow roll into the next year or month.
        components.year = year
        components.month = month
        components.day = day
        guard let date = ExcelDate.calendar.date(from: components) else { return .error(.number) }
        return .number(ExcelDate.serial(from: date).rounded(.down))
    }

    private static func shiftMonths(serial: Double, by months: Int, toEndOfMonth: Bool) -> FormulaValue {
        let parts = ExcelDate.components(from: serial)
        var components = DateComponents()
        components.year = parts.year
        components.month = parts.month + months + (toEndOfMonth ? 1 : 0)
        components.day = toEndOfMonth ? 0 : parts.day
        guard let date = ExcelDate.calendar.date(from: components) else { return .error(.number) }
        return .number(ExcelDate.serial(from: date).rounded(.down))
    }

    // MARK: - Lookup implementations

    private static func index(_ arguments: [FormulaArgument], _ evaluator: FormulaEvaluator) -> FormulaValue {
        guard let first = arguments.first, case .reference(let sheet, let range) = first else {
            return .error(.value)
        }
        guard arguments.count >= 2, case .success(let rowOffset) = evaluator.value(of: arguments[1]).asNumber() else {
            return .error(.value)
        }
        var columnOffset = 1.0
        if arguments.count >= 3 {
            guard case .success(let value) = evaluator.value(of: arguments[2]).asNumber() else {
                return .error(.value)
            }
            columnOffset = value
        } else if range.rowCount == 1 {
            // A single-row range indexes along its columns.
            columnOffset = rowOffset
            return cellOfIndex(sheet, range, row: 1, column: columnOffset, evaluator)
        }
        return cellOfIndex(sheet, range, row: rowOffset, column: columnOffset, evaluator)
    }

    private static func cellOfIndex(_ sheet: Int, _ range: CellRange, row: Double, column: Double,
                                    _ evaluator: FormulaEvaluator) -> FormulaValue {
        let rowIndex = Int(row)
        let columnIndex = Int(column)
        guard rowIndex >= 1, rowIndex <= range.rowCount,
              columnIndex >= 1, columnIndex <= range.columnCount else { return .error(.reference) }
        return evaluator.value(sheetIndex: sheet,
                               row: range.start.row + rowIndex - 1,
                               column: range.start.column + columnIndex - 1)
    }

    private static func match(_ arguments: [FormulaArgument], _ evaluator: FormulaEvaluator) -> FormulaValue {
        guard arguments.count >= 2 else { return .error(.value) }
        let needle = evaluator.value(of: arguments[0])
        var mode = 1.0
        if arguments.count >= 3 {
            guard case .success(let value) = evaluator.value(of: arguments[2]).asNumber() else {
                return .error(.value)
            }
            mode = value
        }

        if mode == 0 {
            let criterion = Criterion(needle)
            var offset = 0
            var found: Int?
            evaluator.forEachValue(arguments[1]) { value in
                offset += 1
                if found == nil, criterion.matches(value) { found = offset }
            }
            guard let found else { return .error(.notAvailable) }
            return .number(Double(found))
        }

        let haystack = evaluator.values(of: arguments[1])

        // Modes 1 and -1 want sorted data and take the closest value that does
        // not overshoot.
        guard case .success(let target) = needle.asNumber() else { return .error(.notAvailable) }
        var best: Int?
        for (offset, value) in haystack.enumerated() {
            guard case .number(let number) = value else { continue }
            if mode > 0 ? number <= target : number >= target { best = offset }
        }
        guard let best else { return .error(.notAvailable) }
        return .number(Double(best + 1))
    }

    private static func lookup(_ arguments: [FormulaArgument], _ evaluator: FormulaEvaluator,
                               vertical: Bool) -> FormulaValue {
        guard arguments.count >= 3, case .reference(let sheet, let range) = arguments[1] else {
            return .error(.value)
        }
        let needle = evaluator.value(of: arguments[0])
        guard case .success(let offset) = evaluator.value(of: arguments[2]).asNumber() else {
            return .error(.value)
        }
        let resultOffset = Int(offset)
        guard resultOffset >= 1,
              resultOffset <= (vertical ? range.columnCount : range.rowCount) else { return .error(.reference) }

        let approximate = arguments.count < 4
            || ((try? evaluator.value(of: arguments[3]).asBoolean().get()) ?? true)
        let criterion = Criterion(needle)
        let span = vertical ? range.rows : range.columns
        var fallback: Int?

        for position in span {
            let probe = vertical
                ? evaluator.value(sheetIndex: sheet, row: position, column: range.start.column)
                : evaluator.value(sheetIndex: sheet, row: range.start.row, column: position)
            if criterion.matches(probe) {
                return result(at: position, resultOffset, sheet, range, vertical, evaluator)
            }
            if approximate, case .success(let a) = probe.asNumber(), case .success(let b) = needle.asNumber(),
               a <= b {
                fallback = position
            }
        }
        guard approximate, let fallback else { return .error(.notAvailable) }
        return result(at: fallback, resultOffset, sheet, range, vertical, evaluator)
    }

    private static func result(at position: Int, _ offset: Int, _ sheet: Int, _ range: CellRange,
                               _ vertical: Bool, _ evaluator: FormulaEvaluator) -> FormulaValue {
        vertical
            ? evaluator.value(sheetIndex: sheet, row: position, column: range.start.column + offset - 1)
            : evaluator.value(sheetIndex: sheet, row: range.start.row + offset - 1, column: position)
    }
}

private extension FormulaValue {
    var textValue: String? {
        if case .text(let value) = self { return value }
        return nil
    }
}
