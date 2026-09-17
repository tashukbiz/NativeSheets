import Foundation

/// Helpers for editing the XML fragments the reader kept verbatim.
enum Fragments {
    static let mainNamespace = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    static let relationshipNamespace = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    static let packageRelationshipNamespace = "http://schemas.openxmlformats.org/package/2006/relationships"
    static let contentTypesNamespace = "http://schemas.openxmlformats.org/package/2006/content-types"

    static let worksheetContentType =
        "application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"
    static let sharedStringsContentType =
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"
    static let stylesContentType =
        "application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"

    static func parse(_ fragment: String?) -> XMLNode? {
        guard let fragment, !fragment.isEmpty else { return nil }
        return try? XMLDocument.parse(Data(fragment.utf8))
    }

    /// Returns the named child, creating it if absent.
    @discardableResult
    static func child(named localName: String, of parent: XMLNode, prefix: String) -> XMLNode {
        if let existing = parent.firstElement(named: localName) { return existing }
        let created = XMLNode(name: prefix + localName)
        parent.children.append(.element(created))
        return created
    }

    static func removeChild(named localName: String, of parent: XMLNode) {
        parent.children.removeAll { child in
            if case .element(let node) = child { return node.localName == localName }
            return false
        }
    }

    static func moveChildFirst(_ target: XMLNode, in parent: XMLNode) {
        parent.children.removeAll { child in
            if case .element(let node) = child { return node === target }
            return false
        }
        parent.children.insert(.element(target), at: 0)
    }
}

/// Collects the workbook's text values into the shared string table that
/// `t="s"` cells index into.
final class SharedStringTable {
    private(set) var strings: [String] = []
    private var indexes: [String: Int] = [:]
    private(set) var totalReferences = 0

    func index(of string: String) -> Int {
        totalReferences += 1
        if let existing = indexes[string] { return existing }
        strings.append(string)
        indexes[string] = strings.count - 1
        return strings.count - 1
    }

    func data(prefix: String) -> Data {
        var writer = XMLWriter()
        writer.open(prefix + "sst", [
            (prefix.isEmpty ? "xmlns" : "xmlns:" + prefix.dropLast(), Fragments.mainNamespace),
            ("count", String(totalReferences)),
            ("uniqueCount", String(strings.count)),
        ])
        for string in strings {
            writer.open(prefix + "si")
            // Leading or trailing space is only kept when space is preserved.
            let needsSpacePreservation = string != string.trimmingCharacters(in: .whitespacesAndNewlines)
            writer.element(prefix + "t", needsSpacePreservation ? [("xml:space", "preserve")] : [], text: string)
            writer.close(prefix + "si")
        }
        writer.close(prefix + "sst")
        return writer.data
    }
}
