import Foundation

/// A parsed XML element, kept as a tree.
///
/// Used for the small parts (workbook, styles, relationships) and to hold
/// worksheet sections the editor does not model, so they can be written back
/// out unchanged. Worksheet cell data never goes through this type.
public final class XMLNode {
    public let name: String
    public var attributes: [String: String]
    public var children: [Child]

    public enum Child {
        case element(XMLNode)
        case text(String)
    }

    init(name: String, attributes: [String: String] = [:], children: [Child] = []) {
        self.name = name
        self.attributes = attributes
        self.children = children
    }

    public var localName: String { XLSXKit.localName(name) }

    public var elements: [XMLNode] {
        children.compactMap { if case .element(let node) = $0 { return node } else { return nil } }
    }

    public func elements(named localName: String) -> [XMLNode] {
        elements.filter { $0.localName == localName }
    }

    public func firstElement(named localName: String) -> XMLNode? {
        elements.first { $0.localName == localName }
    }

    /// Depth-first search, for parts whose nesting varies between producers.
    public func firstDescendant(named localName: String) -> XMLNode? {
        for element in elements {
            if element.localName == localName { return element }
            if let match = element.firstDescendant(named: localName) { return match }
        }
        return nil
    }

    public var textContent: String {
        children.reduce(into: "") { result, child in
            switch child {
            case .text(let value): result += value
            case .element(let node): result += node.textContent
            }
        }
    }

    /// Re-serializes the subtree. Attribute order is normalized, which XML
    /// treats as insignificant.
    public func serialized() -> String {
        var writer = XMLWriter(declaration: false)
        write(into: &writer)
        return writer.text
    }

    private func write(into writer: inout XMLWriter) {
        let sorted = attributes.sorted { $0.key < $1.key }.map { ($0.key, Optional($0.value)) }
        if children.isEmpty {
            writer.empty(name, sorted)
            return
        }
        writer.open(name, sorted)
        for child in children {
            switch child {
            case .text(let value): writer.raw(XMLWriter.escapeText(value))
            case .element(let node): node.write(into: &writer)
            }
        }
        writer.close(name)
    }
}

/// Builds an `XMLNode` tree from SAX events.
final class XMLNodeBuilder {
    private var stack: [XMLNode] = []
    private(set) var root: XMLNode?

    var isFinished: Bool { stack.isEmpty && root != nil }

    func start(_ name: String, _ attributes: [String: String]) {
        let node = XMLNode(name: name, attributes: attributes)
        if let parent = stack.last {
            parent.children.append(.element(node))
        } else {
            root = node
        }
        stack.append(node)
    }

    func text(_ value: String) {
        stack.last?.children.append(.text(value))
    }

    func end() {
        stack.removeLast()
    }
}

public enum XMLDocument {
    /// Parses a whole part into a tree. Only for parts known to be small.
    public static func parse(_ data: Data) throws -> XMLNode {
        let delegate = TreeDelegate()
        let parser = XMLParser(data: data)
        // Prefixes are kept verbatim so that attributes like `r:id` survive a
        // read/write cycle; element matching uses the local name instead.
        parser.shouldProcessNamespaces = false
        parser.delegate = delegate
        guard parser.parse(), let root = delegate.builder.root else {
            throw XLSXError.malformedXML(parser.parserError?.localizedDescription ?? "unparseable part")
        }
        return root
    }

    private final class TreeDelegate: NSObject, XMLParserDelegate {
        let builder = XMLNodeBuilder()

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                    qualifiedName: String?, attributes: [String: String] = [:]) {
            builder.start(qualifiedName ?? name, attributes)
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            builder.text(string)
        }

        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
                    qualifiedName: String?) {
            builder.end()
        }
    }
}
