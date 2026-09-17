import Foundation

/// A parsed formula.
public indirect enum FormulaNode: Sendable {
    case literal(FormulaValue)
    case reference(SheetReference)
    case unary(String, FormulaNode)
    case binary(String, FormulaNode, FormulaNode)
    case call(String, [FormulaNode])
    /// A name the engine does not resolve, reported as `#NAME?`.
    case unresolvedName(String)
}

/// Precedence-climbing parser over the token stream.
public struct FormulaParser {
    private let tokens: [FormulaToken]
    private var index = 0

    private init(_ tokens: [FormulaToken]) {
        self.tokens = tokens
    }

    /// Parses a formula, with or without its leading `=`.
    public static func parse(_ source: String) throws -> FormulaNode {
        var text = source
        if text.hasPrefix("=") { text.removeFirst() }
        var parser = FormulaParser(try FormulaLexer.tokens(of: text))
        let node = try parser.parseExpression(minimumPrecedence: 0)
        guard parser.index == parser.tokens.count else { throw FormulaParseError.unexpectedToken }
        return node
    }

    /// Binding power of each infix operator, loosest first.
    private static let precedence: [String: Int] = [
        "=": 1, "<>": 1, "<": 1, ">": 1, "<=": 1, ">=": 1,
        "&": 2,
        "+": 3, "-": 3,
        "*": 4, "/": 4,
        "^": 5,
    ]

    private mutating func parseExpression(minimumPrecedence: Int) throws -> FormulaNode {
        var left = try parseUnary()

        while index < tokens.count, case .symbol(let symbol) = tokens[index],
              let precedence = FormulaParser.precedence[symbol], precedence >= minimumPrecedence {
            index += 1
            // `^` is right-associative; everything else binds left to right.
            let next = symbol == "^" ? precedence : precedence + 1
            let right = try parseExpression(minimumPrecedence: next)
            left = .binary(symbol, left, right)
        }
        return left
    }

    private mutating func parseUnary() throws -> FormulaNode {
        guard index < tokens.count else { throw FormulaParseError.unexpectedToken }
        if case .symbol(let symbol) = tokens[index], symbol == "-" || symbol == "+" {
            index += 1
            return .unary(symbol, try parseUnary())
        }
        return try parsePostfix()
    }

    private mutating func parsePostfix() throws -> FormulaNode {
        var node = try parsePrimary()
        while index < tokens.count, case .symbol("%") = tokens[index] {
            index += 1
            node = .unary("%", node)
        }
        return node
    }

    private mutating func parsePrimary() throws -> FormulaNode {
        guard index < tokens.count else { throw FormulaParseError.unexpectedToken }
        let token = tokens[index]
        index += 1

        switch token {
        case .number(let number):
            return .literal(.number(number))
        case .string(let text):
            return .literal(.text(text))
        case .error(let error):
            return .literal(.error(error))
        case .reference(let reference):
            return .reference(reference)
        case .name(let name):
            return try parseName(name)
        case .symbol("("):
            let node = try parseExpression(minimumPrecedence: 0)
            try expect(")")
            return node
        case .symbol("{"):
            throw FormulaParseError.unexpectedToken
        default:
            throw FormulaParseError.unexpectedToken
        }
    }

    private mutating func parseName(_ name: String) throws -> FormulaNode {
        guard index < tokens.count, case .symbol("(") = tokens[index] else {
            switch name.uppercased() {
            case "TRUE": return .literal(.boolean(true))
            case "FALSE": return .literal(.boolean(false))
            default: return .unresolvedName(name)
            }
        }
        index += 1

        var arguments: [FormulaNode] = []
        if index < tokens.count, case .symbol(")") = tokens[index] {
            index += 1
            return .call(name.uppercased(), arguments)
        }

        while true {
            // An omitted argument, as in IF(A1,,"no"), reads as blank.
            if index < tokens.count, case .symbol(let symbol) = tokens[index], symbol == "," || symbol == ";" {
                arguments.append(.literal(.empty))
                index += 1
                continue
            }
            arguments.append(try parseExpression(minimumPrecedence: 0))
            guard index < tokens.count, case .symbol(let symbol) = tokens[index] else {
                throw FormulaParseError.unbalancedParentheses
            }
            index += 1
            if symbol == ")" { break }
            guard symbol == "," || symbol == ";" else { throw FormulaParseError.unexpectedToken }
        }
        return .call(name.uppercased(), arguments)
    }

    private mutating func expect(_ symbol: String) throws {
        guard index < tokens.count, case .symbol(symbol) = tokens[index] else {
            throw FormulaParseError.unbalancedParentheses
        }
        index += 1
    }
}

extension FormulaNode {
    /// Every reference the formula reads, used to order recalculation.
    public var references: [SheetReference] {
        switch self {
        case .reference(let reference):
            return [reference]
        case .unary(_, let operand):
            return operand.references
        case .binary(_, let left, let right):
            return left.references + right.references
        case .call(_, let arguments):
            return arguments.flatMap(\.references)
        case .literal, .unresolvedName:
            return []
        }
    }
}
