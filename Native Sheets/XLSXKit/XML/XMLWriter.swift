import Foundation

/// Appends escaped XML to a string buffer.
///
/// Parts are written by hand rather than through a DOM so that a sheet with a
/// million cells never has to exist twice in memory.
public struct XMLWriter {
    public private(set) var text: String

    public init(declaration: Bool = true) {
        text = declaration ? "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n" : ""
        text.reserveCapacity(64 * 1024)
    }

    public var data: Data { Data(text.utf8) }

    public mutating func open(_ name: String, _ attributes: [(String, String?)] = []) {
        text += "<" + name
        appendAttributes(attributes)
        text += ">"
    }

    public mutating func empty(_ name: String, _ attributes: [(String, String?)] = []) {
        text += "<" + name
        appendAttributes(attributes)
        text += "/>"
    }

    public mutating func close(_ name: String) {
        text += "</" + name + ">"
    }

    public mutating func element(_ name: String, _ attributes: [(String, String?)] = [], text content: String) {
        open(name, attributes)
        text += XMLWriter.escapeText(content)
        close(name)
    }

    public mutating func raw(_ fragment: String) {
        text += fragment
    }

    private mutating func appendAttributes(_ attributes: [(String, String?)]) {
        for (name, value) in attributes {
            guard let value else { continue }
            text += " " + name + "=\"" + XMLWriter.escapeAttribute(value) + "\""
        }
    }

    public static func escapeText(_ value: String) -> String {
        var output = ""
        output.reserveCapacity(value.count)
        for character in value.unicodeScalars {
            switch character {
            case "&": output += "&amp;"
            case "<": output += "&lt;"
            case ">": output += "&gt;"
            // Control characters are illegal in XML 1.0; the spreadsheet grid
            // never produces them, but pasted text can.
            case "\u{0}"..."\u{8}", "\u{B}", "\u{C}", "\u{E}"..."\u{1F}":
                continue
            default: output.unicodeScalars.append(character)
            }
        }
        return output
    }

    public static func escapeAttribute(_ value: String) -> String {
        var output = escapeText(value)
        output = output.replacingOccurrences(of: "\"", with: "&quot;")
        output = output.replacingOccurrences(of: "\n", with: "&#10;")
        output = output.replacingOccurrences(of: "\t", with: "&#9;")
        return output
    }
}

extension Double {
    /// Numbers in a sheet part must round-trip exactly without picking up
    /// exponent or locale formatting.
    var xmlNumber: String {
        if self == rounded(), abs(self) < 1e15 {
            return String(Int64(self))
        }
        return "\(self)"
    }
}
