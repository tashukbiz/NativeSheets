import Foundation

/// Turns what someone types into a cell value.
///
/// A spreadsheet infers type from the text: `=…` is a formula, digits are a
/// number, `40%` is a number wearing a percent format, and a recognisable date
/// becomes a serial with a date format. Anything else is text.
public enum CellInput {
    public struct Parsed: Sendable {
        public var value: CellValue
        public var formula: String?
        /// A format the input implies, applied only over `General`.
        public var numberFormat: String?
    }

    public static func parse(_ input: String) -> Parsed {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("=") {
            let body = String(trimmed.dropFirst())
            // A lone `=` is not a formula, just text.
            guard !body.isEmpty else { return Parsed(value: .text(input)) }
            return Parsed(value: .empty, formula: body)
        }

        guard !trimmed.isEmpty else { return Parsed(value: .empty) }

        switch trimmed.uppercased() {
        case "TRUE": return Parsed(value: .boolean(true))
        case "FALSE": return Parsed(value: .boolean(false))
        default: break
        }

        if let number = plainNumber(trimmed) {
            return Parsed(value: .number(number))
        }
        if trimmed.hasSuffix("%"), let number = plainNumber(String(trimmed.dropLast())) {
            return Parsed(value: .number(number / 100), numberFormat: percentFormat(for: trimmed))
        }
        if let serial = dateSerial(trimmed) {
            return Parsed(value: .number(serial.value), numberFormat: serial.format)
        }
        // Leading apostrophe forces text, as it does everywhere else.
        if trimmed.hasPrefix("'") {
            return Parsed(value: .text(String(trimmed.dropFirst())))
        }
        return Parsed(value: .text(input))
    }

    /// Accepts grouping separators, so pasting `1,234.50` gives a number.
    private static func plainNumber(_ text: String) -> Double? {
        if let value = Double(text) { return value }
        let ungrouped = text.replacingOccurrences(of: ",", with: "")
        guard ungrouped != text, !ungrouped.isEmpty else { return nil }
        // Reject anything that was not just digits and separators.
        guard ungrouped.allSatisfy({ $0.isNumber || $0 == "." || $0 == "-" || $0 == "+" }) else { return nil }
        return Double(ungrouped)
    }

    private static func percentFormat(for text: String) -> String {
        let body = text.dropLast()
        guard let separator = body.firstIndex(of: ".") else { return "0%" }
        let decimals = body.distance(from: body.index(after: separator), to: body.endIndex)
        return "0." + String(repeating: "0", count: max(1, decimals)) + "%"
    }

    private static let dateFormats: [(pattern: String, display: String)] = [
        ("yyyy-MM-dd HH:mm", "yyyy-mm-dd hh:mm"),
        ("yyyy-MM-dd", "yyyy-mm-dd"),
        ("dd/MM/yyyy", "dd/mm/yyyy"),
        ("MM/dd/yyyy", "mm/dd/yyyy"),
        ("d MMM yyyy", "d mmm yyyy"),
        ("d MMMM yyyy", "d mmmm yyyy"),
    ]

    private static func dateSerial(_ text: String) -> (value: Double, format: String)? {
        // A bare number is never a date here; that case is handled above.
        guard text.contains("-") || text.contains("/") || text.contains(" ") else { return nil }

        for candidate in dateFormats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = candidate.pattern
            guard let date = formatter.date(from: text) else { continue }
            let serial = ExcelDate.serial(from: date)
            // Reject serials outside the format's own range.
            guard serial >= 1, serial < 2_958_466 else { continue }
            return (candidate.pattern.contains("HH") ? serial : serial.rounded(), candidate.display)
        }
        return nil
    }

    /// The text to show when a cell is opened for editing: its formula if it
    /// has one, otherwise the value as it would be typed back in.
    public static func editingText(for cell: Cell, numberFormat: String) -> String {
        if let formula = cell.formula { return "=" + formula }
        switch cell.value {
        case .empty: return ""
        case .text(let text): return text
        case .boolean(let flag): return flag ? "TRUE" : "FALSE"
        case .error(let code): return code
        case .number(let number):
            // Editing a date shows the date, not its serial.
            if NumberFormat.shared(for: numberFormat).isDateFormat {
                return NumberFormat.shared(for: numberFormat).string(for: .number(number)).text
            }
            return NumberFormat.general(number)
        }
    }
}
