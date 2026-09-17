import Foundation

enum FormulaToken: Equatable {
    case number(Double)
    case string(String)
    case error(FormulaError)
    case reference(SheetReference)
    case name(String)
    case symbol(String)
}

/// Turns formula source into tokens.
///
/// References are recognised here rather than in the parser, because telling
/// `A1` from the name `A1B` needs character-level lookahead.
struct FormulaLexer {
    private let characters: [Character]
    private var index = 0

    init(_ source: String) {
        characters = Array(source)
    }

    static func tokens(of source: String) throws -> [FormulaToken] {
        var lexer = FormulaLexer(source)
        var tokens: [FormulaToken] = []
        while let token = try lexer.next() { tokens.append(token) }
        return tokens
    }

    private mutating func next() throws -> FormulaToken? {
        skipWhitespace()
        guard index < characters.count else { return nil }
        let character = characters[index]

        switch character {
        case "\"":
            return .string(try readString())
        case "#":
            return .error(try readError())
        case "'":
            return .reference(try readQuotedSheetReference())
        case "0"..."9":
            return .number(readNumber())
        case ".":
            // A leading decimal point still starts a number.
            if index + 1 < characters.count, characters[index + 1].isNumber { return .number(readNumber()) }
            index += 1
            return .symbol(".")
        default:
            break
        }

        if let symbol = readSymbol() { return .symbol(symbol) }
        if character.isLetter || character == "_" || character == "$" {
            return try readNameOrReference()
        }
        throw FormulaParseError.unexpectedCharacter(String(character))
    }

    private mutating func skipWhitespace() {
        while index < characters.count, characters[index] == " " || characters[index] == "\n" {
            index += 1
        }
    }

    private mutating func readString() throws -> String {
        index += 1
        var value = ""
        while index < characters.count {
            if characters[index] == "\"" {
                index += 1
                // A doubled quote is a literal quote.
                if index < characters.count, characters[index] == "\"" {
                    value.append("\"")
                    index += 1
                    continue
                }
                return value
            }
            value.append(characters[index])
            index += 1
        }
        throw FormulaParseError.unterminatedString
    }

    private mutating func readError() throws -> FormulaError {
        for candidate in ["#DIV/0!", "#VALUE!", "#REF!", "#NAME?", "#NUM!", "#N/A", "#NULL!"] {
            let end = index + candidate.count
            if end <= characters.count, String(characters[index..<end]).uppercased() == candidate {
                index = end
                return FormulaError(rawValue: candidate)!
            }
        }
        throw FormulaParseError.unexpectedCharacter("#")
    }

    private mutating func readNumber() -> Double {
        var text = ""
        while index < characters.count, characters[index].isNumber || characters[index] == "." {
            text.append(characters[index])
            index += 1
        }
        // Scientific notation, but only when a digit or sign really follows.
        if index < characters.count, characters[index] == "e" || characters[index] == "E" {
            var lookahead = index + 1
            if lookahead < characters.count, characters[lookahead] == "+" || characters[lookahead] == "-" {
                lookahead += 1
            }
            if lookahead < characters.count, characters[lookahead].isNumber {
                while index < lookahead {
                    text.append(characters[index])
                    index += 1
                }
                while index < characters.count, characters[index].isNumber {
                    text.append(characters[index])
                    index += 1
                }
            }
        }
        return Double(text) ?? 0
    }

    private mutating func readSymbol() -> String? {
        let twoCharacter = ["<=", ">=", "<>"]
        if index + 1 < characters.count {
            let pair = String(characters[index...index + 1])
            if twoCharacter.contains(pair) {
                index += 2
                return pair
            }
        }
        let single = "+-*/^&=<>(),;%:"
        if single.contains(characters[index]) {
            let symbol = String(characters[index])
            index += 1
            return symbol
        }
        return nil
    }

    private mutating func readQuotedSheetReference() throws -> SheetReference {
        index += 1
        var name = ""
        while index < characters.count {
            if characters[index] == "'" {
                index += 1
                if index < characters.count, characters[index] == "'" {
                    name.append("'")
                    index += 1
                    continue
                }
                break
            }
            name.append(characters[index])
            index += 1
        }
        guard index < characters.count, characters[index] == "!" else {
            throw FormulaParseError.malformedReference(name)
        }
        index += 1
        guard let range = readRange() else { throw FormulaParseError.malformedReference(name) }
        return SheetReference(sheetName: name, range: range)
    }

    private mutating func readNameOrReference() throws -> FormulaToken {
        let start = index
        var word = ""
        while index < characters.count,
              characters[index].isLetter || characters[index].isNumber
                || characters[index] == "_" || characters[index] == "." || characters[index] == "$" {
            word.append(characters[index])
            index += 1
        }

        // An unquoted sheet name, as in Data!A1.
        if index < characters.count, characters[index] == "!" {
            index += 1
            guard let range = readRange() else { throw FormulaParseError.malformedReference(word) }
            return .reference(SheetReference(sheetName: word, range: range))
        }

        index = start
        if let range = readRange(), index >= characters.count || characters[index] != "(" {
            return .reference(SheetReference(sheetName: nil, range: range))
        }

        index = start + word.count
        return .name(word)
    }

    /// Reads `A1`, `A1:B2` or `A:A`, leaving the cursor put when it is not one.
    private mutating func readRange() -> CellRange? {
        let start = index
        guard let first = readAddress() else {
            index = start
            return nil
        }
        guard index < characters.count, characters[index] == ":" else {
            guard let address = first.address else {
                index = start
                return nil
            }
            return CellRange(address)
        }

        let afterColon = index
        index += 1
        guard let second = readAddress() else {
            index = afterColon
            guard let address = first.address else {
                index = start
                return nil
            }
            return CellRange(address)
        }

        // Whole-column and whole-row references span the sheet's limits.
        let startAddress = CellAddress(row: first.row ?? 1, column: first.column ?? 1)
        let endAddress = CellAddress(
            row: second.row ?? FormulaLexer.maximumRow,
            column: second.column ?? FormulaLexer.maximumColumn
        )
        return CellRange(start: startAddress, end: endAddress)
    }

    static let maximumRow = 1_048_576
    static let maximumColumn = 16_384

    private struct PartialAddress {
        var column: Int?
        var row: Int?
        var address: CellAddress? {
            guard let column, let row else { return nil }
            return CellAddress(row: row, column: column)
        }
    }

    private mutating func readAddress() -> PartialAddress? {
        let start = index
        if index < characters.count, characters[index] == "$" { index += 1 }

        var letters = ""
        while index < characters.count, characters[index].isLetter, letters.count < 3 {
            letters.append(characters[index])
            index += 1
        }
        if index < characters.count, characters[index] == "$" { index += 1 }

        var digits = ""
        while index < characters.count, characters[index].isNumber {
            digits.append(characters[index])
            index += 1
        }

        // Anything still attached is an identifier, not an address.
        if index < characters.count,
           characters[index].isLetter || characters[index] == "_" || characters[index] == "." {
            index = start
            return nil
        }
        if letters.isEmpty && digits.isEmpty {
            index = start
            return nil
        }
        return PartialAddress(
            column: letters.isEmpty ? nil : CellAddress.columnIndex(letters),
            row: digits.isEmpty ? nil : Int(digits)
        )
    }
}

public enum FormulaParseError: Error, Equatable {
    case unexpectedCharacter(String)
    case unterminatedString
    case malformedReference(String)
    case unexpectedToken
    case unbalancedParentheses
}
