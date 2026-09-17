import Foundation

/// A COUNTIF-style criterion: a bare value to equal, or a comparison operator
/// followed by one. Text comparisons ignore case and honour `*` and `?`
/// wildcards.
struct Criterion {
    private enum Comparison: String {
        case equal = "="
        case notEqual = "<>"
        case lessThan = "<"
        case greaterThan = ">"
        case lessOrEqual = "<="
        case greaterOrEqual = ">="
    }

    private let comparison: Comparison
    private let target: FormulaValue
    private let pattern: WildcardPattern?
    /// Set when the criterion is text without wildcards, which compares
    /// directly instead of running the matcher.
    private let plainText: String?
    /// The same text lowercased as ASCII bytes. Comparing bytes avoids the
    /// bridge into Foundation that `caseInsensitiveCompare` pays, which
    /// dominates a recalculation that scans large ranges.
    private let plainTextBytes: [UInt8]?

    init(_ value: FormulaValue) {
        guard case .text(let raw) = value else {
            comparison = .equal
            target = value
            pattern = nil
            plainText = nil
            plainTextBytes = nil
            return
        }

        var text = raw
        var comparison = Comparison.equal
        for candidate in [Comparison.lessOrEqual, .greaterOrEqual, .notEqual, .lessThan, .greaterThan, .equal]
        where text.hasPrefix(candidate.rawValue) {
            comparison = candidate
            text.removeFirst(candidate.rawValue.count)
            break
        }

        self.comparison = comparison
        if let number = Double(text.trimmingCharacters(in: .whitespaces)), !text.isEmpty {
            target = .number(number)
            pattern = nil
            plainText = nil
            plainTextBytes = nil
        } else {
            target = .text(text)
            let wildcards = (comparison == .equal || comparison == .notEqual)
                ? WildcardPattern(text) : nil
            pattern = wildcards
            let plain = (wildcards?.isPlainText == true && !text.isEmpty) ? text : nil
            plainText = plain
            plainTextBytes = plain.flatMap(Criterion.asciiLowercased)
        }
    }

    func matches(_ value: FormulaValue) -> Bool {
        if let plainText {
            guard case .text(let candidate) = value else {
                return comparison == .notEqual
            }
            let equal: Bool
            if let plainTextBytes, let candidateBytes = Criterion.asciiLowercased(candidate) {
                equal = plainTextBytes == candidateBytes
            } else {
                equal = candidate.caseInsensitiveCompare(plainText) == .orderedSame
            }
            return comparison == .notEqual ? !equal : equal
        }
        if let pattern {
            let text = (try? value.asText().get()) ?? ""
            // An empty criterion matches only blank cells.
            let matched = pattern.isEmpty ? value.isBlank : pattern.matches(text)
            return comparison == .notEqual ? !matched : matched
        }

        let ordering = compare(value, target)
        switch comparison {
        case .equal: return ordering == .orderedSame
        case .notEqual: return ordering != .orderedSame
        case .lessThan: return ordering == .orderedAscending
        case .greaterThan: return ordering == .orderedDescending
        case .lessOrEqual: return ordering != .orderedDescending
        case .greaterOrEqual: return ordering != .orderedAscending
        }
    }

    /// Lowercased ASCII bytes, or nil when the text is not plain ASCII and
    /// needs the full Unicode-aware comparison.
    private static func asciiLowercased(_ text: String) -> [UInt8]? {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(text.utf8.count)
        for byte in text.utf8 {
            guard byte < 0x80 else { return nil }
            bytes.append(byte >= 65 && byte <= 90 ? byte + 32 : byte)
        }
        return bytes
    }

    private func compare(_ left: FormulaValue, _ right: FormulaValue) -> ComparisonResult {
        switch (left, right) {
        case (.number(let a), .number(let b)):
            return a == b ? .orderedSame : (a < b ? .orderedAscending : .orderedDescending)
        case (.text(let a), .text(let b)):
            return a.caseInsensitiveCompare(b)
        case (.boolean(let a), .boolean(let b)):
            return a == b ? .orderedSame : (a ? .orderedDescending : .orderedAscending)
        default:
            // Mixed types never compare equal, and a blank is not zero here.
            return .orderedDescending
        }
    }
}

/// Matches `*` (any run) and `?` (one character), case-insensitively, with `~`
/// escaping either.
struct WildcardPattern {
    private let parts: [Part]
    let isEmpty: Bool

    private enum Part: Equatable {
        case literal(String)
        case anyRun
        case anyCharacter
    }

    init(_ pattern: String) {
        isEmpty = pattern.isEmpty
        var parts: [Part] = []
        var literal = ""
        var escaped = false

        for character in pattern.lowercased() {
            if escaped {
                literal.append(character)
                escaped = false
                continue
            }
            switch character {
            case "~": escaped = true
            case "*", "?":
                if !literal.isEmpty {
                    parts.append(.literal(literal))
                    literal = ""
                }
                parts.append(character == "*" ? .anyRun : .anyCharacter)
            default:
                literal.append(character)
            }
        }
        if !literal.isEmpty { parts.append(.literal(literal)) }
        self.parts = parts
    }

    var isPlainText: Bool {
        parts.allSatisfy { if case .literal = $0 { return true } else { return false } }
    }

    func matches(_ text: String) -> Bool {
        let characters = Array(text.lowercased())
        return match(partIndex: 0, textIndex: 0, characters)
    }

    private func match(partIndex: Int, textIndex: Int, _ characters: [Character]) -> Bool {
        guard partIndex < parts.count else { return textIndex == characters.count }

        switch parts[partIndex] {
        case .literal(let literal):
            let end = textIndex + literal.count
            guard end <= characters.count, String(characters[textIndex..<end]) == literal else { return false }
            return match(partIndex: partIndex + 1, textIndex: end, characters)
        case .anyCharacter:
            guard textIndex < characters.count else { return false }
            return match(partIndex: partIndex + 1, textIndex: textIndex + 1, characters)
        case .anyRun:
            for end in textIndex...characters.count
            where match(partIndex: partIndex + 1, textIndex: end, characters) {
                return true
            }
            return false
        }
    }
}
