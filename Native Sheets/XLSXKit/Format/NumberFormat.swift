import Foundation

/// Renders a cell value through an OOXML number format code.
///
/// Format codes are the spreadsheet's own mini-language: up to four
/// semicolon-separated sections (positive, negative, zero, text), digit
/// placeholders, date fields, literals and a bracketed colour.
public struct NumberFormat: Sendable {
    public struct Result: Equatable, Sendable {
        public var text: String
        /// The `[Red]` style colour a section can request.
        public var colorRGB: String?
    }

    private let sections: [Section]
    public let code: String

    public init(code: String) {
        self.code = code
        self.sections = NumberFormat.split(code).map(Section.init)
    }

    /// True when the first section renders its value as a date or a time.
    public var isDateFormat: Bool { sections.first?.isDate ?? false }

    public func string(for value: CellValue) -> Result {
        switch value {
        case .empty:
            return Result(text: "")
        case .error(let message):
            return Result(text: message)
        case .boolean(let flag):
            return Result(text: flag ? "TRUE" : "FALSE")
        case .text(let string):
            // The fourth section, when present, formats text; otherwise text
            // passes through untouched.
            guard sections.count >= 4 else { return Result(text: string) }
            return Result(text: sections[3].renderText(string), colorRGB: sections[3].color)
        case .number(let number):
            return render(number)
        }
    }

    private func render(_ number: Double) -> Result {
        guard !sections.isEmpty else { return Result(text: NumberFormat.general(number)) }

        let section: Section
        var magnitude = number
        if number < 0, sections.count >= 2 {
            section = sections[1]
            // A dedicated negative section supplies its own sign, if any.
            magnitude = section.suppliesNegativeSign ? -number : number
        } else if number == 0, sections.count >= 3 {
            section = sections[2]
        } else {
            section = sections[0]
        }
        return Result(text: section.render(magnitude), colorRGB: section.color)
    }

    /// Splits on semicolons that are not inside quotes or brackets.
    private static func split(_ code: String) -> [String] {
        var sections: [String] = []
        var current = ""
        var inQuotes = false
        var inBrackets = false
        var iterator = code.makeIterator()

        while let character = iterator.next() {
            switch character {
            case "\"": inQuotes.toggle(); current.append(character)
            case "[" where !inQuotes: inBrackets = true; current.append(character)
            case "]" where !inQuotes: inBrackets = false; current.append(character)
            case ";" where !inQuotes && !inBrackets:
                sections.append(current)
                current = ""
            default: current.append(character)
            }
        }
        sections.append(current)
        return sections
    }

    /// The `General` format: as many digits as needed, no grouping.
    public static func general(_ number: Double) -> String {
        if number == number.rounded(), abs(number) < 1e15 {
            return String(Int64(number))
        }
        // Spreadsheets show at most 11 significant digits in a default column.
        var text = String(format: "%.10g", number)
        if text.contains("e") {
            text = String(format: "%.5E", number)
                .replacingOccurrences(of: "E", with: "E+")
                .replacingOccurrences(of: "E+-", with: "E-")
        }
        return text
    }
}
