import Foundation

enum StylesReader {
    static func read(_ data: Data) throws -> WorkbookStyles {
        let root = try XMLDocument.parse(data)
        var table = WorkbookStyles()

        var numberFormats: [Int: String] = [:]
        for node in root.firstElement(named: "numFmts")?.elements(named: "numFmt") ?? [] {
            guard let id = node.attributes.intAttribute("numFmtId"),
                  let code = node.attributes.attribute("formatCode") else { continue }
            numberFormats[id] = code
        }

        let fonts = (root.firstElement(named: "fonts")?.elements(named: "font") ?? []).map(readFont)
        let fills = (root.firstElement(named: "fills")?.elements(named: "fill") ?? []).map(readFill)
        let borders = (root.firstElement(named: "borders")?.elements(named: "border") ?? []).map(readBorder)
        let formats = (root.firstElement(named: "cellXfs")?.elements(named: "xf") ?? []).map(readFormat)

        table.adopt(
            numberFormats: numberFormats,
            fonts: fonts.isEmpty ? [WorkbookStyles.Font()] : fonts,
            fills: fills.isEmpty ? [WorkbookStyles.Fill(patternType: "none")] : fills,
            borders: borders.isEmpty ? [WorkbookStyles.Border()] : borders,
            cellFormats: formats.isEmpty ? [WorkbookStyles.CellFormat()] : formats,
            preserved: preservedSections(root)
        )
        table.namespacePrefix = namespacePrefix(root.name)
        return table
    }

    /// Sections regenerated from the model on save; everything else is carried
    /// over untouched.
    private static let regenerated: Set<String> = ["numFmts", "fonts", "fills", "borders", "cellXfs"]

    private static func preservedSections(_ root: XMLNode) -> [String: String] {
        var sections: [String: String] = [:]
        for element in root.elements where !regenerated.contains(element.localName) {
            sections[element.localName] = element.serialized()
        }
        return sections
    }

    private static func readFont(_ node: XMLNode) -> WorkbookStyles.Font {
        var font = WorkbookStyles.Font()
        if let name = node.firstElement(named: "name")?.attributes.attribute("val") { font.name = name }
        if let size = node.firstElement(named: "sz")?.attributes.doubleAttribute("val") { font.size = size }
        font.bold = node.firstElement(named: "b").map { $0.attributes.boolAttribute("val", default: true) } ?? false
        font.italic = node.firstElement(named: "i").map { $0.attributes.boolAttribute("val", default: true) } ?? false
        font.underline = node.firstElement(named: "u") != nil
        font.strikethrough = node.firstElement(named: "strike") != nil
        font.colorRGB = node.firstElement(named: "color")?.attributes.attribute("rgb")
        return font
    }

    private static func readFill(_ node: XMLNode) -> WorkbookStyles.Fill {
        var fill = WorkbookStyles.Fill()
        guard let pattern = node.firstElement(named: "patternFill") else { return fill }
        fill.patternType = pattern.attributes.attribute("patternType")
        fill.foregroundRGB = pattern.firstElement(named: "fgColor")?.attributes.attribute("rgb")
        fill.backgroundRGB = pattern.firstElement(named: "bgColor")?.attributes.attribute("rgb")
        return fill
    }

    private static func readBorder(_ node: XMLNode) -> WorkbookStyles.Border {
        func edge(_ name: String) -> WorkbookStyles.Edge? {
            guard let element = node.firstElement(named: name),
                  let style = element.attributes.attribute("style") else { return nil }
            return WorkbookStyles.Edge(style: style, colorRGB: element.firstElement(named: "color")?.attributes.attribute("rgb"))
        }
        return WorkbookStyles.Border(left: edge("left"), right: edge("right"), top: edge("top"), bottom: edge("bottom"))
    }

    private static func readFormat(_ node: XMLNode) -> WorkbookStyles.CellFormat {
        var format = WorkbookStyles.CellFormat()
        format.numberFormatID = node.attributes.intAttribute("numFmtId") ?? 0
        format.fontID = node.attributes.intAttribute("fontId") ?? 0
        format.fillID = node.attributes.intAttribute("fillId") ?? 0
        format.borderID = node.attributes.intAttribute("borderId") ?? 0
        if let alignment = node.firstElement(named: "alignment") {
            format.alignment.horizontal = alignment.attributes.attribute("horizontal")
                .flatMap(WorkbookStyles.HorizontalAlignment.init(rawValue:))
            format.alignment.vertical = alignment.attributes.attribute("vertical")
                .flatMap(WorkbookStyles.VerticalAlignment.init(rawValue:))
            format.alignment.wrapText = alignment.attributes.boolAttribute("wrapText", default: false)
        }
        return format
    }
}

extension WorkbookStyles {
    mutating func adopt(
        numberFormats: [Int: String],
        fonts: [Font],
        fills: [Fill],
        borders: [Border],
        cellFormats: [CellFormat],
        preserved: [String: String]
    ) {
        self.customNumberFormats = numberFormats
        self.fonts = fonts
        self.fills = fills
        self.borders = borders
        self.cellFormats = cellFormats
        self.preserved = preserved
    }
}
