import Foundation

/// The part of a qualified name after the prefix: `x:worksheet` → `worksheet`.
///
/// Producers disagree about prefixes. The sample workbook prefixes every
/// SpreadsheetML element with `x:`; Excel itself uses a default namespace.
/// Matching on the local name accepts both.
@inline(__always)
func localName(_ qualified: String) -> String {
    guard let colon = qualified.lastIndex(of: ":") else { return qualified }
    return String(qualified[qualified.index(after: colon)...])
}

/// The prefix part of a qualified name, including the colon: `x:worksheet` →
/// `x:`. Regenerated elements reuse the source's prefix so that preserved
/// fragments stay in scope of the same namespace declaration.
@inline(__always)
func namespacePrefix(_ qualified: String) -> String {
    guard let colon = qualified.firstIndex(of: ":") else { return "" }
    return String(qualified[...colon])
}

extension Dictionary where Key == String, Value == String {
    /// Attribute lookup that ignores the prefix, so `r:id` and `id` both match.
    func attribute(_ name: String) -> String? {
        if let exact = self[name] { return exact }
        let suffix = ":" + name
        for (key, value) in self where key.hasSuffix(suffix) { return value }
        return nil
    }

    func intAttribute(_ name: String) -> Int? {
        attribute(name).flatMap(Int.init)
    }

    func doubleAttribute(_ name: String) -> Double? {
        attribute(name).flatMap(Double.init)
    }

    /// OOXML booleans are `1`/`0` or `true`/`false`, and absent means the
    /// schema default.
    func boolAttribute(_ name: String, default defaultValue: Bool) -> Bool {
        guard let raw = attribute(name) else { return defaultValue }
        return raw == "1" || raw == "true"
    }
}
