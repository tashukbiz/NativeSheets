import Foundation

/// Conversion between spreadsheet date serials and calendar components.
///
/// Serial 1 is 1 January 1900. The format also counts a 29 February 1900 that
/// never existed, for compatibility with Lotus 1-2-3, so serials at or below 60
/// need a day of correction.
public enum ExcelDate {
    public struct Parts: Equatable, Sendable {
        public var year = 1900
        public var month = 1
        public var day = 1
        public var hour = 0
        public var minute = 0
        public var second = 0
        public var weekday = 1
        public var fractionalSecond: Double = 0
    }

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private static let unixEpochSerial = 25569.0

    public static func date(from serial: Double) -> Date {
        let corrected = serial < 61 ? serial + 1 : serial
        return Date(timeIntervalSince1970: (corrected - unixEpochSerial) * 86400)
    }

    public static func serial(from date: Date) -> Double {
        let serial = date.timeIntervalSince1970 / 86400 + unixEpochSerial
        return serial < 61 ? serial - 1 : serial
    }

    public static func components(from serial: Double) -> Parts {
        // Split before converting so that rounding in the time part cannot
        // spill a day boundary into the wrong date.
        let wholeDays = serial.rounded(.down)
        let dayFraction = serial - wholeDays
        let totalSeconds = (dayFraction * 86400).rounded()

        let date = ExcelDate.date(from: wholeDays)
        let fields = calendar.dateComponents([.year, .month, .day, .weekday], from: date)

        var parts = Parts()
        parts.year = fields.year ?? 1900
        parts.month = fields.month ?? 1
        parts.day = fields.day ?? 1
        parts.weekday = fields.weekday ?? 1
        parts.hour = Int(totalSeconds / 3600) % 24
        parts.minute = Int(totalSeconds / 60) % 60
        parts.second = Int(totalSeconds) % 60
        parts.fractionalSecond = dayFraction * 86400 - totalSeconds.rounded(.down)
        return parts
    }

    static let monthNames = ["January", "February", "March", "April", "May", "June",
                             "July", "August", "September", "October", "November", "December"]
    static let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    static func render(field: String, parts: Parts, use12Hour: Bool) -> String {
        func padded(_ value: Int, _ width: Int) -> String {
            String(format: "%0\(width)d", value)
        }

        switch field {
        case "yy": return padded(parts.year % 100, 2)
        case "yyy", "yyyy", "yyyyy": return String(parts.year)
        case "m": return String(parts.month)
        case "mm": return padded(parts.month, 2)
        case "mmm": return String(monthNames[parts.month - 1].prefix(3))
        case "mmmm": return monthNames[parts.month - 1]
        case "mmmmm": return String(monthNames[parts.month - 1].prefix(1))
        case "d": return String(parts.day)
        case "dd": return padded(parts.day, 2)
        case "ddd": return String(dayNames[(parts.weekday - 1) % 7].prefix(3))
        case "dddd", "ddddd": return dayNames[(parts.weekday - 1) % 7]
        case "h", "hh":
            let hour = use12Hour ? (parts.hour % 12 == 0 ? 12 : parts.hour % 12) : parts.hour
            return field == "h" ? String(hour) : padded(hour, 2)
        case "n": return String(parts.minute)
        case "nn": return padded(parts.minute, 2)
        case "s": return String(parts.second)
        case "ss": return padded(parts.second, 2)
        default: return ""
        }
    }
}

extension NumberFormat {
    /// True when the format renders its value as a date, which the grid uses to
    /// decide alignment and how to parse typed input back.
    public var rendersDates: Bool {
        NumberFormat.dateFormatCache.isDate(code)
    }

    /// Format codes repeat across thousands of cells, so parsing is cached.
    static let cache = FormatCache()
    private static let dateFormatCache = FormatCache()

    public static func shared(for code: String) -> NumberFormat {
        cache.format(for: code)
    }
}

/// Thread-safe cache of parsed format codes.
final class FormatCache: @unchecked Sendable {
    private var formats: [String: NumberFormat] = [:]
    private let lock = NSLock()

    func format(for code: String) -> NumberFormat {
        lock.lock()
        defer { lock.unlock() }
        if let existing = formats[code] { return existing }
        let parsed = NumberFormat(code: code)
        formats[code] = parsed
        return parsed
    }

    func isDate(_ code: String) -> Bool {
        format(for: code).isDateFormat
    }
}
