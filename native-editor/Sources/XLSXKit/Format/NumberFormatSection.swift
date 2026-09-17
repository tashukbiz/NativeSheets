import Foundation

/// One semicolon-separated part of a format code, parsed into tokens once.
struct Section: Sendable {
    enum Token: Sendable {
        case integerDigit(Character)
        case fractionDigit(Character)
        case decimalPoint
        case literal(String)
        case percent
        case textPlaceholder
        case dateField(String)
        case elapsed(Character, width: Int)
        case meridiem(String)
    }

    private(set) var tokens: [Token] = []
    private(set) var color: String?
    private(set) var isDate = false
    private(set) var suppliesNegativeSign = false
    private(set) var isGeneral = false

    private var minimumIntegerDigits = 0
    private var fractionDigits = 0
    private var minimumFractionDigits = 0
    private var grouped = false
    private var scale: Double = 1

    init(_ code: String) {
        parse(code)
    }

    // MARK: - Parsing

    private mutating func parse(_ code: String) {
        if code.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare("General") == .orderedSame {
            isGeneral = true
            return
        }
        let characters = Array(code)
        var index = 0
        var sawDecimalPoint = false
        var literal = ""
        // `m` means minutes next to an hour or a second field, months otherwise.
        var previousDateField: String?

        func flushLiteral() {
            if !literal.isEmpty {
                tokens.append(.literal(literal))
                literal = ""
            }
        }

        while index < characters.count {
            let character = characters[index]

            switch character {
            case "\"":
                index += 1
                while index < characters.count, characters[index] != "\"" {
                    literal.append(characters[index])
                    index += 1
                }
                index += 1
                continue

            case "\\":
                index += 1
                if index < characters.count {
                    literal.append(characters[index])
                    index += 1
                }
                continue

            case "_":
                // Reserves the width of the next character; rendered as a space.
                index += 2
                literal.append(" ")
                continue

            case "*":
                // Repeat-fill to the column width, which a grid cell ignores.
                index += 2
                continue

            case "[":
                var content = ""
                index += 1
                while index < characters.count, characters[index] != "]" {
                    content.append(characters[index])
                    index += 1
                }
                index += 1
                switch Section.classifyBracket(content) {
                case .elapsed(let unit, let width):
                    flushLiteral()
                    tokens.append(.elapsed(unit, width: width))
                    previousDateField = String(unit)
                    isDate = true
                case .color(let rgb):
                    color = rgb
                case .ignored:
                    break
                }
                continue

            case "0", "#", "?":
                flushLiteral()
                if sawDecimalPoint {
                    tokens.append(.fractionDigit(character))
                    fractionDigits += 1
                    if character == "0" { minimumFractionDigits = fractionDigits }
                } else {
                    tokens.append(.integerDigit(character))
                    if character == "0" { minimumIntegerDigits += 1 }
                }
                index += 1
                continue

            case ".":
                flushLiteral()
                sawDecimalPoint = true
                tokens.append(.decimalPoint)
                index += 1
                continue

            case ",":
                // Between digit placeholders it groups; after them it scales.
                if tokens.contains(where: { if case .integerDigit = $0 { return true } else { return false } }) {
                    let next = index + 1 < characters.count ? characters[index + 1] : " "
                    if next == "0" || next == "#" || next == "?" {
                        grouped = true
                    } else {
                        scale /= 1000
                    }
                } else {
                    literal.append(character)
                }
                index += 1
                continue

            case "%":
                flushLiteral()
                scale *= 100
                tokens.append(.percent)
                index += 1
                continue

            case "@":
                flushLiteral()
                tokens.append(.textPlaceholder)
                index += 1
                continue

            case "-" where tokens.isEmpty && literal.isEmpty:
                suppliesNegativeSign = true
                literal.append(character)
                index += 1
                continue

            case "(" where tokens.isEmpty && literal.isEmpty:
                suppliesNegativeSign = true
                literal.append(character)
                index += 1
                continue

            default:
                if let field = matchDateField(characters, at: &index, previous: previousDateField) {
                    flushLiteral()
                    if field.hasPrefix("A") || field.hasPrefix("a") {
                        tokens.append(.meridiem(field))
                    } else {
                        tokens.append(.dateField(field))
                        previousDateField = field
                    }
                    isDate = true
                    continue
                }
                literal.append(character)
                index += 1
            }
        }
        flushLiteral()
    }

    private enum Bracket {
        case elapsed(Character, width: Int)
        case color(String)
        /// Conditions and locale ids ([$-409], [>100]) do not change how a
        /// single value renders here.
        case ignored
    }

    private static func classifyBracket(_ content: String) -> Bracket {
        let lowercased = content.lowercased()
        if let unit = lowercased.first, "hms".contains(unit), lowercased.allSatisfy({ $0 == unit }) {
            return .elapsed(unit, width: content.count)
        }
        if let rgb = colors[lowercased] { return .color(rgb) }
        return .ignored
    }

    /// Matches the longest run of a date field character at `index`.
    private func matchDateField(_ characters: [Character], at index: inout Int,
                                previous: String?) -> String? {
        let character = characters[index]

        if character == "A" || character == "a" {
            for candidate in ["AM/PM", "am/pm", "A/P", "a/p"] {
                let end = index + candidate.count
                if end <= characters.count, String(characters[index..<end]) == candidate {
                    index = end
                    return candidate
                }
            }
            return nil
        }

        let lowercased = Character(character.lowercased())
        guard "ymdhs".contains(lowercased) else { return nil }

        var run = ""
        while index < characters.count, Character(characters[index].lowercased()) == lowercased {
            run.append(lowercased)
            index += 1
        }

        if lowercased == "m" {
            let followsHour = previous?.hasPrefix("h") == true
            var lookahead = index
            while lookahead < characters.count, !characters[lookahead].isLetter { lookahead += 1 }
            let precedesSecond = lookahead < characters.count
                && Character(characters[lookahead].lowercased()) == "s"
            if followsHour || precedesSecond {
                return run == "m" ? "n" : "nn"  // minutes
            }
        }
        return run
    }

    private static let colors: [String: String] = [
        "black": "FF000000", "blue": "FF0000FF", "cyan": "FF00FFFF", "green": "FF008000",
        "magenta": "FFFF00FF", "red": "FFFF0000", "white": "FFFFFFFF", "yellow": "FFFFFF00",
    ]

    // MARK: - Rendering

    func renderText(_ string: String) -> String {
        guard !isGeneral else { return string }
        return tokens.reduce(into: "") { result, token in
            switch token {
            case .textPlaceholder: result += string
            case .literal(let value): result += value
            default: break
            }
        }
    }

    func render(_ number: Double) -> String {
        guard !isGeneral, !tokens.isEmpty else { return NumberFormat.general(number) }
        return isDate ? renderDate(number) : renderNumber(number)
    }

    private func renderNumber(_ number: Double) -> String {
        let scaled = number * scale
        let negative = scaled < 0 && !suppliesNegativeSign
        let magnitude = abs(scaled)

        let rounded = (magnitude * pow(10, Double(fractionDigits))).rounded() / pow(10, Double(fractionDigits))
        var integerPart = String(Int64(rounded.rounded(.down)))
        if integerPart.count < minimumIntegerDigits {
            integerPart = String(repeating: "0", count: minimumIntegerDigits - integerPart.count) + integerPart
        }
        if integerPart == "0" && minimumIntegerDigits == 0 { integerPart = "" }
        if grouped { integerPart = Section.group(integerPart) }

        var fractionPart = ""
        if fractionDigits > 0 {
            let digits = String(format: "%.\(fractionDigits)f", rounded)
            fractionPart = String(digits.suffix(fractionDigits))
            while fractionPart.count > minimumFractionDigits, fractionPart.hasSuffix("0") {
                fractionPart.removeLast()
            }
        }

        var output = negative ? "-" : ""
        var usedInteger = false
        var usedFraction = false

        for token in tokens {
            switch token {
            case .integerDigit:
                if !usedInteger {
                    output += integerPart
                    usedInteger = true
                }
            case .decimalPoint:
                if !fractionPart.isEmpty { output += "." }
            case .fractionDigit:
                if !usedFraction {
                    output += fractionPart
                    usedFraction = true
                }
            case .percent:
                output += "%"
            case .literal(let value):
                output += value
            case .textPlaceholder, .dateField, .elapsed, .meridiem:
                break
            }
        }
        return output
    }

    private static func group(_ digits: String) -> String {
        guard digits.count > 3 else { return digits }
        var grouped = ""
        for (offset, character) in digits.enumerated() {
            if offset > 0, (digits.count - offset) % 3 == 0 { grouped.append(",") }
            grouped.append(character)
        }
        return grouped
    }

    private func renderDate(_ serial: Double) -> String {
        let parts = ExcelDate.components(from: serial)
        var output = ""

        // A 12-hour clock is only used when the section asks for AM/PM.
        let uses12Hour = tokens.contains { if case .meridiem = $0 { return true } else { return false } }

        for token in tokens {
            switch token {
            case .dateField(let field):
                output += ExcelDate.render(field: field, parts: parts, use12Hour: uses12Hour)
            case .elapsed(let unit, let width):
                let total: Double
                switch unit {
                case "h": total = (serial * 24).rounded(.towardZero)
                case "m": total = (serial * 24 * 60).rounded(.towardZero)
                default: total = (serial * 24 * 3600).rounded(.towardZero)
                }
                output += String(format: "%0\(width)d", Int(total))
            case .meridiem(let style):
                let isAfternoon = parts.hour >= 12
                if style.lowercased() == "a/p" {
                    output += isAfternoon ? (style.hasPrefix("A") ? "P" : "p") : (style.hasPrefix("A") ? "A" : "a")
                } else {
                    output += isAfternoon ? (style.hasPrefix("A") ? "PM" : "pm") : (style.hasPrefix("A") ? "AM" : "am")
                }
            case .literal(let value):
                output += value
            case .integerDigit, .fractionDigit, .decimalPoint, .percent, .textPlaceholder:
                break
            }
        }
        return output
    }
}
