import Foundation

/// Reads an `.xlsx` package into a `Workbook`.
public enum XLSXReader {
    public static func read(contentsOf url: URL) throws -> Workbook {
        try read(data: Data(contentsOf: url, options: .mappedIfSafe))
    }

    public static func read(data: Data) throws -> Workbook {
        let archive = try ZipArchive(data: data)

        var package = PackageParts()
        for entry in archive.entries {
            package[entry.name] = try archive.read(entry)
        }

        guard let workbookData = package["xl/workbook.xml"] else {
            throw XLSXError.missingPart("xl/workbook.xml")
        }
        let workbookRoot = try XMLDocument.parse(workbookData)
        let relationships = try readRelationships(package["xl/_rels/workbook.xml.rels"])
        let sharedStrings = try package["xl/sharedStrings.xml"].map(readSharedStrings) ?? []

        var styles = WorkbookStyles()
        if let stylesData = package["xl/styles.xml"] {
            styles = try StylesReader.read(stylesData)
        }

        var sheets: [Worksheet] = []
        for node in workbookRoot.firstElement(named: "sheets")?.elements(named: "sheet") ?? [] {
            let name = node.attributes.attribute("name") ?? "Sheet\(sheets.count + 1)"
            var sheet = Worksheet(name: name)
            sheet.sheetID = node.attributes.intAttribute("sheetId") ?? (sheets.count + 1)
            sheet.relationshipID = node.attributes.attribute("id") ?? ""
            sheet.partName = relationships[sheet.relationshipID]
                ?? "xl/worksheets/sheet\(sheets.count + 1).xml"

            if let sheetData = package[sheet.partName] {
                sheet = try WorksheetReader.read(sheetData, into: sheet, sharedStrings: sharedStrings)
            }
            applyViewSettings(to: &sheet)
            sheets.append(sheet)
        }

        guard !sheets.isEmpty else { throw XLSXError.noWorksheets }

        var workbook = Workbook(sheets: sheets)
        workbook.styles = styles
        workbook.package = package
        workbook.usedRelationshipIDs = Set(relationships.keys)
        workbook.namespacePrefix = namespacePrefix(workbookRoot.name)
        workbook.activeSheetIndex = min(
            workbookRoot.firstDescendant(named: "workbookView")?.attributes.intAttribute("activeTab") ?? 0,
            sheets.count - 1
        )
        for element in workbookRoot.elements where element.localName != "sheets" {
            workbook.preserved[element.localName] = element.serialized()
        }
        return workbook
    }

    // MARK: - Package parts

    private static func readRelationships(_ data: Data?) throws -> [String: String] {
        guard let data else { return [:] }
        let root = try XMLDocument.parse(data)
        var map: [String: String] = [:]
        for node in root.elements(named: "Relationship") {
            guard let id = node.attributes.attribute("Id"),
                  let target = node.attributes.attribute("Target") else { continue }
            map[id] = normalizePartPath(target)
        }
        return map
    }

    /// Relationship targets are either absolute in the package (`/xl/…`) or
    /// relative to the part that declares them (`worksheets/sheet1.xml`).
    private static func normalizePartPath(_ target: String) -> String {
        if target.hasPrefix("/") { return String(target.dropFirst()) }
        if target.hasPrefix("xl/") { return target }
        return "xl/" + target
    }

    private static func readSharedStrings(_ data: Data) throws -> [String] {
        let root = try XMLDocument.parse(data)
        return root.elements(named: "si").map { item in
            // A string with mixed formatting arrives as a sequence of runs.
            if item.firstElement(named: "r") != nil {
                return item.elements(named: "r").map { $0.firstElement(named: "t")?.textContent ?? "" }.joined()
            }
            return item.firstElement(named: "t")?.textContent ?? item.textContent
        }
    }

    /// Pulls display settings out of the preserved `sheetPr` and `sheetViews`
    /// fragments so the grid can honour them.
    private static func applyViewSettings(to sheet: inout Worksheet) {
        sheet.validations = DataValidationReader.read(sheet.preserved["dataValidations"])
        if let fragment = sheet.preserved["sheetPr"],
           let node = try? XMLDocument.parse(Data(fragment.utf8)) {
            sheet.tabColor = node.firstDescendant(named: "tabColor")?.attributes.attribute("rgb")
        }
        guard let fragment = sheet.preserved["sheetViews"],
              let node = try? XMLDocument.parse(Data(fragment.utf8)),
              let view = node.firstDescendant(named: "sheetView") else { return }

        sheet.showGridLines = view.attributes.boolAttribute("showGridLines", default: true)
        if let pane = view.firstElement(named: "pane"), pane.attributes.attribute("state")?.hasPrefix("frozen") == true {
            sheet.freeze = FreezePane(
                columns: pane.attributes.intAttribute("xSplit") ?? 0,
                rows: pane.attributes.intAttribute("ySplit") ?? 0
            )
        }
    }
}
