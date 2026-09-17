import Foundation

/// Serializes `xl/styles.xml` from the style table.
///
/// Only called once a style has actually been added; an untouched workbook
/// keeps its original bytes.
struct StylesWriter {
    let styles: WorkbookStyles

    private static let sectionOrder = [
        "numFmts", "fonts", "fills", "borders", "cellStyleXfs", "cellXfs",
        "cellStyles", "dxfs", "tableStyles", "colors", "extLst",
    ]

    func data() -> Data {
        let prefix = styles.namespacePrefix
        var writer = XMLWriter()
        writer.open(prefix + "styleSheet", [
            (prefix.isEmpty ? "xmlns" : "xmlns:" + prefix.dropLast(), Fragments.mainNamespace)
        ])

        for section in StylesWriter.sectionOrder {
            switch section {
            case "numFmts": writeNumberFormats(into: &writer)
            case "fonts": writeFonts(into: &writer)
            case "fills": writeFills(into: &writer)
            case "borders": writeBorders(into: &writer)
            case "cellXfs": writeCellFormats(into: &writer)
            case "cellStyleXfs":
                writer.raw(styles.preserved["cellStyleXfs"] ?? defaultCellStyleFormats())
            default:
                if let preserved = styles.preserved[section] { writer.raw(preserved) }
            }
        }

        writer.close(prefix + "styleSheet")
        return writer.data
    }

    private func defaultCellStyleFormats() -> String {
        let prefix = styles.namespacePrefix
        var writer = XMLWriter(declaration: false)
        writer.open(prefix + "cellStyleXfs", [("count", "1")])
        writer.empty(prefix + "xf", [("numFmtId", "0"), ("fontId", "0"), ("fillId", "0"), ("borderId", "0")])
        writer.close(prefix + "cellStyleXfs")
        return writer.text
    }

    private func writeNumberFormats(into writer: inout XMLWriter) {
        guard !styles.customNumberFormats.isEmpty else { return }
        let prefix = styles.namespacePrefix
        writer.open(prefix + "numFmts", [("count", String(styles.customNumberFormats.count))])
        for id in styles.customNumberFormats.keys.sorted() {
            writer.empty(prefix + "numFmt", [
                ("numFmtId", String(id)),
                ("formatCode", styles.customNumberFormats[id]),
            ])
        }
        writer.close(prefix + "numFmts")
    }

    private func writeFonts(into writer: inout XMLWriter) {
        let prefix = styles.namespacePrefix
        writer.open(prefix + "fonts", [("count", String(styles.fonts.count))])
        for font in styles.fonts {
            writer.open(prefix + "font")
            if font.bold { writer.empty(prefix + "b") }
            if font.italic { writer.empty(prefix + "i") }
            if font.underline { writer.empty(prefix + "u") }
            if font.strikethrough { writer.empty(prefix + "strike") }
            writer.empty(prefix + "sz", [("val", font.size.xmlNumber)])
            if let color = font.colorRGB { writer.empty(prefix + "color", [("rgb", color)]) }
            writer.empty(prefix + "name", [("val", font.name)])
            writer.close(prefix + "font")
        }
        writer.close(prefix + "fonts")
    }

    private func writeFills(into writer: inout XMLWriter) {
        let prefix = styles.namespacePrefix
        writer.open(prefix + "fills", [("count", String(styles.fills.count))])
        for fill in styles.fills {
            writer.open(prefix + "fill")
            let pattern = fill.patternType ?? "none"
            if fill.foregroundRGB == nil && fill.backgroundRGB == nil {
                writer.empty(prefix + "patternFill", [("patternType", pattern)])
            } else {
                writer.open(prefix + "patternFill", [("patternType", pattern)])
                if let foreground = fill.foregroundRGB {
                    writer.empty(prefix + "fgColor", [("rgb", foreground)])
                }
                if let background = fill.backgroundRGB {
                    writer.empty(prefix + "bgColor", [("rgb", background)])
                }
                writer.close(prefix + "patternFill")
            }
            writer.close(prefix + "fill")
        }
        writer.close(prefix + "fills")
    }

    private func writeBorders(into writer: inout XMLWriter) {
        let prefix = styles.namespacePrefix
        writer.open(prefix + "borders", [("count", String(styles.borders.count))])
        for border in styles.borders {
            writer.open(prefix + "border")
            // CT_Border fixes this order.
            for (name, edge) in [("left", border.left), ("right", border.right),
                                 ("top", border.top), ("bottom", border.bottom)] {
                guard let edge else {
                    writer.empty(prefix + name)
                    continue
                }
                if let color = edge.colorRGB {
                    writer.open(prefix + name, [("style", edge.style)])
                    writer.empty(prefix + "color", [("rgb", color)])
                    writer.close(prefix + name)
                } else {
                    writer.empty(prefix + name, [("style", edge.style)])
                }
            }
            writer.empty(prefix + "diagonal")
            writer.close(prefix + "border")
        }
        writer.close(prefix + "borders")
    }

    private func writeCellFormats(into writer: inout XMLWriter) {
        let prefix = styles.namespacePrefix
        writer.open(prefix + "cellXfs", [("count", String(styles.cellFormats.count))])
        for format in styles.cellFormats {
            let alignment = format.alignment
            let hasAlignment = alignment.horizontal != nil || alignment.vertical != nil || alignment.wrapText
            let attributes: [(String, String?)] = [
                ("numFmtId", String(format.numberFormatID)),
                ("fontId", String(format.fontID)),
                ("fillId", String(format.fillID)),
                ("borderId", String(format.borderID)),
                ("xfId", "0"),
                ("applyNumberFormat", format.numberFormatID != 0 ? "1" : nil),
                ("applyFont", format.fontID != 0 ? "1" : nil),
                ("applyFill", format.fillID != 0 ? "1" : nil),
                ("applyBorder", format.borderID != 0 ? "1" : nil),
                ("applyAlignment", hasAlignment ? "1" : nil),
            ]
            guard hasAlignment else {
                writer.empty(prefix + "xf", attributes)
                continue
            }
            writer.open(prefix + "xf", attributes)
            writer.empty(prefix + "alignment", [
                ("horizontal", alignment.horizontal?.rawValue),
                ("vertical", alignment.vertical?.rawValue),
                ("wrapText", alignment.wrapText ? "1" : nil),
            ])
            writer.close(prefix + "xf")
        }
        writer.close(prefix + "cellXfs")
    }
}
