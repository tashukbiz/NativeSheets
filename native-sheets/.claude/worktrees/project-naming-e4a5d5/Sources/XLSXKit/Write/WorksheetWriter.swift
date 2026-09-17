import Foundation

/// Serializes one worksheet part.
struct WorksheetWriter {
    let sheet: Worksheet
    let sharedStrings: SharedStringTable

    /// CT_Worksheet fixes the order of its children, and Excel rejects a part
    /// that gets it wrong. Sections the editor does not model are slotted back
    /// into their place here.
    private static let sectionOrder = [
        "sheetPr", "dimension", "sheetViews", "sheetFormatPr", "cols", "sheetData",
        "sheetCalcPr", "sheetProtection", "protectedRanges", "scenarios", "autoFilter",
        "sortState", "dataConsolidate", "customSheetViews", "mergeCells", "phoneticPr",
        "conditionalFormatting", "dataValidations", "hyperlinks", "printOptions",
        "pageMargins", "pageSetup", "headerFooter", "rowBreaks", "colBreaks",
        "customProperties", "cellWatches", "ignoredErrors", "smartTags", "drawing",
        "drawingHF", "picture", "oleObjects", "controls", "webPublishItems", "tableParts",
        "extLst",
    ]

    func data() -> Data {
        let prefix = sheet.namespacePrefix
        var writer = XMLWriter()
        writer.open(prefix + "worksheet", [
            (prefix.isEmpty ? "xmlns" : "xmlns:" + prefix.dropLast(), Fragments.mainNamespace),
            ("xmlns:r", Fragments.relationshipNamespace),
        ])

        for section in WorksheetWriter.sectionOrder {
            switch section {
            case "sheetPr": writer.raw(sheetProperties())
            case "dimension": writer.raw(dimension())
            case "sheetViews": writer.raw(sheetViews())
            case "sheetFormatPr": writer.raw(sheetFormat())
            case "cols": writer.raw(columns())
            case "sheetData": writeSheetData(into: &writer)
            case "mergeCells": writer.raw(mergeCells())
            default:
                if let preserved = sheet.preserved[section] { writer.raw(preserved) }
            }
        }

        writer.close(prefix + "worksheet")
        return writer.data
    }

    // MARK: - Sections

    /// Patches the original fragment rather than rebuilding it, so unmodelled
    /// attributes (outline settings, zoom, the stored selection) survive.
    private func sheetProperties() -> String {
        let node = Fragments.parse(sheet.preserved["sheetPr"])
            ?? XMLNode(name: sheet.namespacePrefix + "sheetPr")
        if let color = sheet.tabColor {
            Fragments.child(named: "tabColor", of: node, prefix: sheet.namespacePrefix)
                .attributes["rgb"] = color
        } else {
            Fragments.removeChild(named: "tabColor", of: node)
        }
        return node.children.isEmpty && node.attributes.isEmpty ? "" : node.serialized()
    }

    private func sheetViews() -> String {
        let prefix = sheet.namespacePrefix
        let node = Fragments.parse(sheet.preserved["sheetViews"]) ?? XMLNode(name: prefix + "sheetViews")
        let view = node.firstDescendant(named: "sheetView") ?? {
            let created = XMLNode(name: prefix + "sheetView", attributes: ["workbookViewId": "0"])
            node.children.append(.element(created))
            return created
        }()

        if sheet.showGridLines {
            view.attributes.removeValue(forKey: "showGridLines")
        } else {
            view.attributes["showGridLines"] = "0"
        }

        if let freeze = sheet.freeze, freeze.rows > 0 || freeze.columns > 0 {
            let pane = Fragments.child(named: "pane", of: view, prefix: prefix)
            pane.attributes = [
                "xSplit": freeze.columns > 0 ? String(freeze.columns) : "",
                "ySplit": freeze.rows > 0 ? String(freeze.rows) : "",
                "topLeftCell": CellAddress(row: freeze.rows + 1, column: freeze.columns + 1).a1,
                "activePane": "bottomRight",
                "state": "frozen",
            ].filter { !$0.value.isEmpty }
            // A pane must precede the selections that reference it.
            Fragments.moveChildFirst(pane, in: view)
        } else {
            Fragments.removeChild(named: "pane", of: view)
        }
        return node.serialized()
    }

    private func dimension() -> String {
        guard let range = sheet.usedRange else { return "" }
        var writer = XMLWriter(declaration: false)
        writer.empty(sheet.namespacePrefix + "dimension", [("ref", range.a1)])
        return writer.text
    }

    private func sheetFormat() -> String {
        var writer = XMLWriter(declaration: false)
        writer.empty(sheet.namespacePrefix + "sheetFormatPr", [
            ("defaultRowHeight", sheet.defaultRowHeight.xmlNumber),
            ("defaultColWidth", sheet.defaultColumnWidth.xmlNumber),
        ])
        return writer.text
    }

    private func columns() -> String {
        let spans = sheet.columns.filter { $0.width != nil || $0.hidden || $0.styleIndex != nil }
        guard !spans.isEmpty else { return "" }
        let prefix = sheet.namespacePrefix
        var writer = XMLWriter(declaration: false)
        writer.open(prefix + "cols")
        for span in spans {
            writer.empty(prefix + "col", [
                ("min", String(span.first)),
                ("max", String(span.last)),
                ("width", span.width?.xmlNumber),
                ("customWidth", span.width != nil ? "1" : nil),
                ("style", span.styleIndex.map(String.init)),
                ("hidden", span.hidden ? "1" : nil),
            ])
        }
        writer.close(prefix + "cols")
        return writer.text
    }

    private func mergeCells() -> String {
        guard !sheet.merges.isEmpty else { return "" }
        let prefix = sheet.namespacePrefix
        var writer = XMLWriter(declaration: false)
        writer.open(prefix + "mergeCells", [("count", String(sheet.merges.count))])
        for merge in sheet.merges {
            writer.empty(prefix + "mergeCell", [("ref", merge.a1)])
        }
        writer.close(prefix + "mergeCells")
        return writer.text
    }

    // MARK: - Cells

    private func writeSheetData(into writer: inout XMLWriter) {
        let prefix = sheet.namespacePrefix
        writer.open(prefix + "sheetData")
        for index in sheet.rows.keys.sorted() {
            guard let row = sheet.rows[index], !row.isDefault else { continue }
            let columns = row.cells.filter { !$0.value.isDefault }.keys.sorted()

            writer.open(prefix + "row", [
                ("r", String(index)),
                ("spans", columns.isEmpty ? nil : "\(columns[0]):\(columns[columns.count - 1])"),
                ("ht", row.height?.xmlNumber),
                ("customHeight", row.height != nil ? "1" : nil),
                ("s", row.styleIndex.map(String.init)),
                ("customFormat", row.styleIndex != nil ? "1" : nil),
                ("hidden", row.hidden ? "1" : nil),
            ])
            for column in columns {
                write(row.cells[column]!, at: CellAddress(row: index, column: column), into: &writer)
            }
            writer.close(prefix + "row")
        }
        writer.close(prefix + "sheetData")
    }

    private func write(_ cell: Cell, at address: CellAddress, into writer: inout XMLWriter) {
        let prefix = sheet.namespacePrefix
        let attributes: [(String, String?)] = [
            ("r", address.a1),
            ("s", cell.styleIndex == 0 ? nil : String(cell.styleIndex)),
            ("t", cellType(for: cell)),
        ]

        guard cell.formula != nil || !cell.value.isEmpty else {
            writer.empty(prefix + "c", attributes)
            return
        }

        writer.open(prefix + "c", attributes)
        if let formula = cell.formula {
            // The leading `=` belongs to the editor, not the file.
            writer.element(prefix + "f", text: formula)
        }
        switch cell.value {
        case .empty:
            break
        case .number(let number):
            writer.element(prefix + "v", text: number.xmlNumber)
        case .boolean(let flag):
            writer.element(prefix + "v", text: flag ? "1" : "0")
        case .error(let code):
            writer.element(prefix + "v", text: code)
        case .text(let string):
            // An empty result is stored as a bare cell rather than an entry in
            // the shared string table.
            if string.isEmpty { break }
            if cell.formula != nil {
                writer.element(prefix + "v", text: string)
            } else {
                writer.element(prefix + "v", text: String(sharedStrings.index(of: string)))
            }
        }
        writer.close(prefix + "c")
    }

    /// Stored text is a shared-string index; a formula's cached text is `str`.
    private func cellType(for cell: Cell) -> String? {
        switch cell.value {
        case .text(let string) where string.isEmpty: return nil
        case .text: return cell.formula == nil ? "s" : "str"
        case .boolean: return "b"
        case .error: return "e"
        case .number, .empty: return nil
        }
    }
}
