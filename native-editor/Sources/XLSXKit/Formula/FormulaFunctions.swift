import Foundation

/// The built-in function library.
enum FormulaFunctions {
    static func call(_ name: String, _ nodes: [FormulaNode], in evaluator: FormulaEvaluator) -> FormulaValue {
        // These decide for themselves which arguments to evaluate.
        switch name {
        case "IF": return ifFunction(nodes, evaluator)
        case "IFS": return ifs(nodes, evaluator)
        case "IFERROR": return ifError(nodes, evaluator, catching: { _ in true })
        case "IFNA": return ifError(nodes, evaluator, catching: { $0 == .notAvailable })
        case "AND": return booleanChain(nodes, evaluator, requiringAll: true)
        case "OR": return booleanChain(nodes, evaluator, requiringAll: false)
        case "SWITCH": return switchFunction(nodes, evaluator)
        case "CHOOSE": return choose(nodes, evaluator)
        case "ROW": return positional(nodes, evaluator, axis: \.row)
        case "COLUMN": return positional(nodes, evaluator, axis: \.column)
        default: break
        }

        let arguments = nodes.map { evaluator.argument(for: $0) }
        for argument in arguments {
            if case .value(.error(let error)) = argument, !errorTolerant.contains(name) {
                return .error(error)
            }
        }
        return apply(name, arguments, evaluator)
    }

    private static let errorTolerant: Set<String> = [
        "ISERROR", "ISERR", "ISNA", "ISBLANK", "ISNUMBER", "ISTEXT", "ISLOGICAL", "ERROR.TYPE", "NA",
    ]

    private static func apply(_ name: String, _ arguments: [FormulaArgument],
                              _ evaluator: FormulaEvaluator) -> FormulaValue {
        switch name {
        // MARK: Math
        case "SUM": return reduceNumbers(arguments, evaluator, initial: 0, +)
        case "PRODUCT":
            let numbers = numericValues(arguments, evaluator)
            return numbers.isEmpty ? .number(0) : .number(numbers.reduce(1, *))
        case "ABS": return unaryMath(arguments, evaluator, abs)
        case "SQRT": return unaryMath(arguments, evaluator) { $0 < 0 ? .nan : sqrt($0) }
        case "EXP": return unaryMath(arguments, evaluator, exp)
        case "LN": return unaryMath(arguments, evaluator) { $0 <= 0 ? .nan : log($0) }
        case "LOG10": return unaryMath(arguments, evaluator) { $0 <= 0 ? .nan : log10($0) }
        case "SIGN": return unaryMath(arguments, evaluator) { $0 == 0 ? 0 : ($0 < 0 ? -1 : 1) }
        case "INT": return unaryMath(arguments, evaluator) { $0.rounded(.down) }
        case "TRUNC": return rounding(arguments, evaluator, rule: .towardZero)
        case "ROUND": return rounding(arguments, evaluator, rule: .toNearestOrAwayFromZero)
        case "ROUNDUP": return rounding(arguments, evaluator, rule: .awayFromZero)
        case "ROUNDDOWN": return rounding(arguments, evaluator, rule: .towardZero)
        case "LOG": return logarithm(arguments, evaluator)
        case "POWER": return binaryMath(arguments, evaluator) { pow($0, $1) }
        case "MOD": return modulo(arguments, evaluator)
        case "CEILING": return stepped(arguments, evaluator, up: true)
        case "FLOOR": return stepped(arguments, evaluator, up: false)
        case "PI": return .number(.pi)
        case "RAND": return .number(Double.random(in: 0..<1))
        case "RANDBETWEEN": return randomBetween(arguments, evaluator)

        // MARK: Statistics
        case "COUNT":
            return .number(Double(numericValues(arguments, evaluator).count))
        case "COUNTA":
            var count = 0
            for argument in arguments {
                evaluator.forEachValue(argument) { if !$0.isBlank { count += 1 } }
            }
            return .number(Double(count))
        case "COUNTBLANK":
            var count = 0
            for argument in arguments {
                evaluator.forEachValue(argument) { if $0.isBlank { count += 1 } }
            }
            return .number(Double(count))
        case "AVERAGE":
            let numbers = numericValues(arguments, evaluator)
            guard !numbers.isEmpty else { return .error(.divideByZero) }
            return .number(numbers.reduce(0, +) / Double(numbers.count))
        case "MIN":
            let numbers = numericValues(arguments, evaluator)
            return .number(numbers.min() ?? 0)
        case "MAX":
            let numbers = numericValues(arguments, evaluator)
            return .number(numbers.max() ?? 0)
        case "MEDIAN":
            let sorted = numericValues(arguments, evaluator).sorted()
            guard !sorted.isEmpty else { return .error(.number) }
            let middle = sorted.count / 2
            return .number(sorted.count.isMultiple(of: 2)
                ? (sorted[middle - 1] + sorted[middle]) / 2
                : sorted[middle])
        case "STDEV", "STDEVP", "VAR", "VARP":
            return spread(name, numericValues(arguments, evaluator))
        case "LARGE", "SMALL":
            return ranked(name, arguments, evaluator)

        // MARK: Conditional aggregation
        case "COUNTIF": return countIf(arguments, evaluator)
        case "COUNTIFS": return countIfs(arguments, evaluator)
        case "SUMIF": return sumIf(arguments, evaluator)
        case "SUMIFS": return sumIfs(arguments, evaluator)
        case "AVERAGEIF": return averageIf(arguments, evaluator)

        // MARK: Logical
        case "NOT":
            guard let first = arguments.first else { return .error(.value) }
            switch evaluator.value(of: first).asBoolean() {
            case .success(let flag): return .boolean(!flag)
            case .failure(let error): return .error(error)
            }
        case "XOR":
            var trueCount = 0
            for argument in arguments {
                evaluator.forEachValue(argument) {
                    if case .success(true) = $0.asBoolean() { trueCount += 1 }
                }
            }
            return .boolean(!trueCount.isMultiple(of: 2))
        case "TRUE": return .boolean(true)
        case "FALSE": return .boolean(false)

        default:
            return FormulaFunctions.applyTextAndLookup(name, arguments, evaluator)
        }
    }

    // MARK: - Lazy functions

    private static func ifFunction(_ nodes: [FormulaNode], _ evaluator: FormulaEvaluator) -> FormulaValue {
        guard nodes.count >= 2 else { return .error(.value) }
        let condition = evaluator.evaluate(nodes[0])
        if let error = condition.errorValue { return .error(error) }
        switch condition.asBoolean() {
        case .failure(let error):
            return .error(error)
        case .success(let flag):
            if flag { return evaluator.evaluate(nodes[1]) }
            return nodes.count >= 3 ? evaluator.evaluate(nodes[2]) : .boolean(false)
        }
    }

    private static func ifs(_ nodes: [FormulaNode], _ evaluator: FormulaEvaluator) -> FormulaValue {
        var index = 0
        while index + 1 < nodes.count {
            let condition = evaluator.evaluate(nodes[index])
            if let error = condition.errorValue { return .error(error) }
            if case .success(true) = condition.asBoolean() { return evaluator.evaluate(nodes[index + 1]) }
            index += 2
        }
        return .error(.notAvailable)
    }

    private static func ifError(_ nodes: [FormulaNode], _ evaluator: FormulaEvaluator,
                                catching matches: (FormulaError) -> Bool) -> FormulaValue {
        guard nodes.count >= 2 else { return .error(.value) }
        let value = evaluator.evaluate(nodes[0])
        if let error = value.errorValue, matches(error) { return evaluator.evaluate(nodes[1]) }
        return value
    }

    private static func booleanChain(_ nodes: [FormulaNode], _ evaluator: FormulaEvaluator,
                                     requiringAll: Bool) -> FormulaValue {
        var sawValue = false
        var result = requiringAll
        for node in nodes {
            let argument = evaluator.argument(for: node)
            var failure: FormulaError?
            evaluator.forEachValue(argument) { value in
                if let error = value.errorValue { failure = error; return }
                // Blank cells inside a range are skipped, as in a spreadsheet.
                if value.isBlank, case .reference = argument { return }
                guard case .success(let flag) = value.asBoolean() else { return }
                sawValue = true
                result = requiringAll ? (result && flag) : (result || flag)
            }
            if let failure { return .error(failure) }
        }
        return sawValue ? .boolean(result) : .error(.value)
    }

    private static func switchFunction(_ nodes: [FormulaNode], _ evaluator: FormulaEvaluator) -> FormulaValue {
        guard nodes.count >= 3 else { return .error(.value) }
        let subject = evaluator.evaluate(nodes[0])
        var index = 1
        while index + 1 < nodes.count {
            if evaluator.evaluate(nodes[index]) == subject { return evaluator.evaluate(nodes[index + 1]) }
            index += 2
        }
        // A lone trailing argument is the default.
        return index < nodes.count ? evaluator.evaluate(nodes[index]) : .error(.notAvailable)
    }

    private static func choose(_ nodes: [FormulaNode], _ evaluator: FormulaEvaluator) -> FormulaValue {
        guard let first = nodes.first else { return .error(.value) }
        guard case .success(let selector) = evaluator.evaluate(first).asNumber() else { return .error(.value) }
        let index = Int(selector)
        guard index >= 1, index < nodes.count else { return .error(.value) }
        return evaluator.evaluate(nodes[index])
    }

    private static func positional(_ nodes: [FormulaNode], _ evaluator: FormulaEvaluator,
                                   axis: KeyPath<CellAddress, Int>) -> FormulaValue {
        guard let first = nodes.first else { return .number(Double(evaluator.address[keyPath: axis])) }
        guard case .reference(_, let range) = evaluator.argument(for: first) else { return .error(.value) }
        return .number(Double(range.start[keyPath: axis]))
    }

    // MARK: - Numeric helpers

    static func numericValues(_ arguments: [FormulaArgument], _ evaluator: FormulaEvaluator) -> [Double] {
        var numbers: [Double] = []
        for argument in arguments {
            switch argument {
            case .value(let value):
                // A literal argument is coerced; a cell is only counted when it
                // really holds a number.
                if case .success(let number) = value.asNumber(), !value.isBlank { numbers.append(number) }
            case .reference:
                evaluator.forEachValue(argument) { value in
                    if case .number(let number) = value { numbers.append(number) }
                }
            }
        }
        return numbers
    }

    private static func reduceNumbers(_ arguments: [FormulaArgument], _ evaluator: FormulaEvaluator,
                                      initial: Double, _ combine: (Double, Double) -> Double) -> FormulaValue {
        var result = initial
        for argument in arguments {
            switch argument {
            case .value(let value):
                switch value.asNumber() {
                case .success(let number): result = combine(result, number)
                case .failure(let error): return .error(error)
                }
            case .reference:
                var failure: FormulaError?
                evaluator.forEachValue(argument) { value in
                    if let error = value.errorValue { failure = failure ?? error; return }
                    if case .number(let number) = value { result = combine(result, number) }
                }
                if let failure { return .error(failure) }
            }
        }
        return .number(result)
    }

    private static func unaryMath(_ arguments: [FormulaArgument], _ evaluator: FormulaEvaluator,
                                  _ body: (Double) -> Double) -> FormulaValue {
        guard let first = arguments.first else { return .error(.value) }
        switch evaluator.value(of: first).asNumber() {
        case .failure(let error): return .error(error)
        case .success(let number):
            let result = body(number)
            return result.isNaN ? .error(.number) : .number(result)
        }
    }

    private static func binaryMath(_ arguments: [FormulaArgument], _ evaluator: FormulaEvaluator,
                                   _ body: (Double, Double) -> Double) -> FormulaValue {
        guard arguments.count >= 2,
              case .success(let a) = evaluator.value(of: arguments[0]).asNumber(),
              case .success(let b) = evaluator.value(of: arguments[1]).asNumber() else { return .error(.value) }
        let result = body(a, b)
        return result.isNaN || result.isInfinite ? .error(.number) : .number(result)
    }

    private static func rounding(_ arguments: [FormulaArgument], _ evaluator: FormulaEvaluator,
                                 rule: FloatingPointRoundingRule) -> FormulaValue {
        guard let first = arguments.first,
              case .success(let number) = evaluator.value(of: first).asNumber() else { return .error(.value) }
        var digits = 0.0
        if arguments.count >= 2 {
            guard case .success(let value) = evaluator.value(of: arguments[1]).asNumber() else {
                return .error(.value)
            }
            digits = value
        }
        let factor = pow(10, digits.rounded(.towardZero))
        return .number((number * factor).rounded(rule) / factor)
    }

    private static func logarithm(_ arguments: [FormulaArgument], _ evaluator: FormulaEvaluator) -> FormulaValue {
        guard let first = arguments.first,
              case .success(let number) = evaluator.value(of: first).asNumber(), number > 0 else {
            return .error(.number)
        }
        var base = 10.0
        if arguments.count >= 2 {
            guard case .success(let value) = evaluator.value(of: arguments[1]).asNumber(), value > 0, value != 1 else {
                return .error(.number)
            }
            base = value
        }
        return .number(log(number) / log(base))
    }

    private static func modulo(_ arguments: [FormulaArgument], _ evaluator: FormulaEvaluator) -> FormulaValue {
        guard arguments.count >= 2,
              case .success(let number) = evaluator.value(of: arguments[0]).asNumber(),
              case .success(let divisor) = evaluator.value(of: arguments[1]).asNumber() else { return .error(.value) }
        guard divisor != 0 else { return .error(.divideByZero) }
        // The result takes the divisor's sign, unlike C's remainder.
        return .number(number - divisor * (number / divisor).rounded(.down))
    }

    private static func stepped(_ arguments: [FormulaArgument], _ evaluator: FormulaEvaluator,
                                up: Bool) -> FormulaValue {
        guard arguments.count >= 2,
              case .success(let number) = evaluator.value(of: arguments[0]).asNumber(),
              case .success(let step) = evaluator.value(of: arguments[1]).asNumber() else { return .error(.value) }
        guard step != 0 else { return .number(0) }
        let quotient = number / step
        return .number(step * (up ? quotient.rounded(.up) : quotient.rounded(.down)))
    }

    private static func randomBetween(_ arguments: [FormulaArgument], _ evaluator: FormulaEvaluator) -> FormulaValue {
        guard arguments.count >= 2,
              case .success(let low) = evaluator.value(of: arguments[0]).asNumber(),
              case .success(let high) = evaluator.value(of: arguments[1]).asNumber(), low <= high else {
            return .error(.number)
        }
        return .number(Double(Int.random(in: Int(low)...Int(high))))
    }

    private static func spread(_ name: String, _ numbers: [Double]) -> FormulaValue {
        let isSample = name == "STDEV" || name == "VAR"
        guard numbers.count >= (isSample ? 2 : 1) else { return .error(.divideByZero) }
        let mean = numbers.reduce(0, +) / Double(numbers.count)
        let sumOfSquares = numbers.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        let variance = sumOfSquares / Double(numbers.count - (isSample ? 1 : 0))
        return .number(name.hasPrefix("STDEV") ? sqrt(variance) : variance)
    }

    private static func ranked(_ name: String, _ arguments: [FormulaArgument],
                               _ evaluator: FormulaEvaluator) -> FormulaValue {
        guard arguments.count >= 2,
              case .success(let position) = evaluator.value(of: arguments[1]).asNumber() else {
            return .error(.value)
        }
        let sorted = numericValues([arguments[0]], evaluator).sorted()
        let index = Int(position)
        guard index >= 1, index <= sorted.count else { return .error(.number) }
        return .number(name == "LARGE" ? sorted[sorted.count - index] : sorted[index - 1])
    }

    // MARK: - Criteria

    private static func countIf(_ arguments: [FormulaArgument], _ evaluator: FormulaEvaluator) -> FormulaValue {
        guard arguments.count >= 2 else { return .error(.value) }
        let criterion = Criterion(evaluator.value(of: arguments[1]))
        var count = 0
        evaluator.forEachValue(arguments[0]) { if criterion.matches($0) { count += 1 } }
        return .number(Double(count))
    }

    private static func countIfs(_ arguments: [FormulaArgument], _ evaluator: FormulaEvaluator) -> FormulaValue {
        guard arguments.count >= 2, arguments.count.isMultiple(of: 2) else { return .error(.value) }
        if arguments.count == 2 { return countIf(arguments, evaluator) }
        return .number(Double(matchingOffsets(arguments, evaluator, from: 0)?.count ?? 0))
    }

    private static func sumIf(_ arguments: [FormulaArgument], _ evaluator: FormulaEvaluator) -> FormulaValue {
        guard arguments.count >= 2 else { return .error(.value) }
        let criterion = Criterion(evaluator.value(of: arguments[1]))
        let candidates = evaluator.values(of: arguments[0])
        let summed = arguments.count >= 3 ? evaluator.values(of: arguments[2]) : candidates

        var total = 0.0
        for (offset, value) in candidates.enumerated() where criterion.matches(value) {
            guard offset < summed.count, case .number(let number) = summed[offset] else { continue }
            total += number
        }
        return .number(total)
    }

    private static func sumIfs(_ arguments: [FormulaArgument], _ evaluator: FormulaEvaluator) -> FormulaValue {
        guard arguments.count >= 3, !arguments.count.isMultiple(of: 2) else { return .error(.value) }
        if arguments.count == 3 {
            return sumIf([arguments[1], arguments[2], arguments[0]], evaluator)
        }
        guard let offsets = matchingOffsets(arguments, evaluator, from: 1) else { return .error(.value) }
        let summed = evaluator.values(of: arguments[0])
        var total = 0.0
        for offset in offsets where offset < summed.count {
            if case .number(let number) = summed[offset] { total += number }
        }
        return .number(total)
    }

    private static func averageIf(_ arguments: [FormulaArgument], _ evaluator: FormulaEvaluator) -> FormulaValue {
        guard arguments.count >= 2 else { return .error(.value) }
        let criterion = Criterion(evaluator.value(of: arguments[1]))
        let candidates = evaluator.values(of: arguments[0])
        let averaged = arguments.count >= 3 ? evaluator.values(of: arguments[2]) : candidates

        var total = 0.0
        var count = 0
        for (offset, value) in candidates.enumerated() where criterion.matches(value) {
            guard offset < averaged.count, case .number(let number) = averaged[offset] else { continue }
            total += number
            count += 1
        }
        return count == 0 ? .error(.divideByZero) : .number(total / Double(count))
    }

    /// Offsets within the criteria ranges that satisfy every range/criterion
    /// pair, starting at `start`.
    private static func matchingOffsets(_ arguments: [FormulaArgument], _ evaluator: FormulaEvaluator,
                                        from start: Int) -> Set<Int>? {
        var matches: Set<Int>?
        var index = start
        while index + 1 < arguments.count {
            let values = evaluator.values(of: arguments[index])
            let criterion = Criterion(evaluator.value(of: arguments[index + 1]))
            var current: Set<Int> = []
            for (offset, value) in values.enumerated() where criterion.matches(value) {
                current.insert(offset)
            }
            matches = matches.map { $0.intersection(current) } ?? current
            index += 2
        }
        return matches
    }
}
