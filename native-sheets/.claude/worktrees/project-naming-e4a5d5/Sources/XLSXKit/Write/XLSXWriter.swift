import Foundation

/// Writes a `Workbook` back out as an `.xlsx` package.
///
/// Parts the editor understands are regenerated; everything else is copied from
/// the package the workbook was read from, byte for byte.
public enum XLSXWriter {
    public static func write(_ workbook: Workbook, to url: URL) throws {
        try data(for: workbook).write(to: url, options: .atomic)
    }

    public static func data(for workbook: Workbook) throws -> Data {
        var package = workbook.package
        let prefix = workbook.namespacePrefix

        let sharedStrings = SharedStringTable()
        for sheet in workbook.sheets {
            package[sheet.partName] = WorksheetWriter(sheet: sheet, sharedStrings: sharedStrings).data()
        }
        package["xl/sharedStrings.xml"] = sharedStrings.data(prefix: prefix)

        for orphan in orphanedSheetParts(workbook) {
            package[orphan] = nil
            package[relationshipPath(for: orphan)] = nil
        }

        package["xl/workbook.xml"] = workbookPart(workbook)
        package["xl/_rels/workbook.xml.rels"] = workbookRelationships(workbook, existing: package)
        package["[Content_Types].xml"] = contentTypes(workbook, existing: package)
        if package["_rels/.rels"] == nil {
            package["_rels/.rels"] = packageRelationships()
        }
        if workbook.styles.isModified || package["xl/styles.xml"] == nil {
            package["xl/styles.xml"] = StylesWriter(styles: workbook.styles).data()
        }

        // OOXML readers expect the content types part first.
        var names = package.order
        names.removeAll { $0 == "[Content_Types].xml" }
        names.insert("[Content_Types].xml", at: 0)

        return ZipWriter.archive(names.compactMap { name in
            package[name].map { ZipWriter.Entry(name: name, data: $0) }
        })
    }

    // MARK: - Parts

    private static func orphanedSheetParts(_ workbook: Workbook) -> [String] {
        let live = Set(workbook.sheets.map(\.partName))
        return workbook.package.order.filter { $0.hasPrefix("xl/worksheets/") && $0.hasSuffix(".xml") && !live.contains($0) }
    }

    private static func relationshipPath(for part: String) -> String {
        let components = part.split(separator: "/")
        let file = components.last.map(String.init) ?? part
        return components.dropLast().joined(separator: "/") + "/_rels/" + file + ".rels"
    }

    /// CT_Workbook fixes the order of its children.
    private static let workbookSectionOrder = [
        "fileVersion", "fileSharing", "workbookPr", "workbookProtection", "bookViews",
        "sheets", "functionGroups", "externalReferences", "definedNames", "calcPr",
        "oleSize", "customWorkbookViews", "pivotCaches", "smartTagPr", "smartTagTypes",
        "webPublishing", "fileRecoveryPr", "webPublishObjects", "extLst",
    ]

    private static func workbookPart(_ workbook: Workbook) -> Data {
        let prefix = workbook.namespacePrefix
        var writer = XMLWriter()
        writer.open(prefix + "workbook", [
            (prefix.isEmpty ? "xmlns" : "xmlns:" + prefix.dropLast(), Fragments.mainNamespace),
            ("xmlns:r", Fragments.relationshipNamespace),
        ])

        for section in workbookSectionOrder {
            switch section {
            case "bookViews":
                writer.raw(bookViews(workbook))
            case "sheets":
                writer.open(prefix + "sheets")
                for sheet in workbook.sheets {
                    writer.empty(prefix + "sheet", [
                        ("name", sheet.name),
                        ("sheetId", String(sheet.sheetID)),
                        ("r:id", sheet.relationshipID),
                    ])
                }
                writer.close(prefix + "sheets")
            default:
                if let preserved = workbook.preserved[section] { writer.raw(preserved) }
            }
        }

        writer.close(prefix + "workbook")
        return writer.data
    }

    private static func bookViews(_ workbook: Workbook) -> String {
        let prefix = workbook.namespacePrefix
        let node = Fragments.parse(workbook.preserved["bookViews"]) ?? XMLNode(name: prefix + "bookViews")
        let view = node.firstDescendant(named: "workbookView") ?? {
            let created = XMLNode(name: prefix + "workbookView")
            node.children.append(.element(created))
            return created
        }()
        view.attributes["activeTab"] = String(max(0, workbook.activeSheetIndex))
        return node.serialized()
    }

    private static func workbookRelationships(_ workbook: Workbook, existing: PackageParts) -> Data {
        var relationships: [(id: String, type: String, target: String)] = []
        var used = Set<String>()

        // Keep non-worksheet relationships (styles, theme, shared strings) as
        // they were, so their ids stay valid for parts that reference them.
        if let data = existing["xl/_rels/workbook.xml.rels"], let root = try? XMLDocument.parse(data) {
            for node in root.elements(named: "Relationship") {
                guard let id = node.attributes.attribute("Id"),
                      let type = node.attributes.attribute("Type"),
                      let target = node.attributes.attribute("Target") else { continue }
                if type.hasSuffix("/worksheet") { continue }
                relationships.append((id, type, target))
                used.insert(id)
            }
        }
        if !relationships.contains(where: { $0.type.hasSuffix("/styles") }) {
            relationships.append((unusedID(&used), Fragments.relationshipNamespace + "/styles", "styles.xml"))
        }
        if !relationships.contains(where: { $0.type.hasSuffix("/sharedStrings") }) {
            relationships.append((unusedID(&used), Fragments.relationshipNamespace + "/sharedStrings", "sharedStrings.xml"))
        }

        for sheet in workbook.sheets {
            let target = sheet.partName.hasPrefix("xl/") ? String(sheet.partName.dropFirst(3)) : sheet.partName
            relationships.append((sheet.relationshipID, Fragments.relationshipNamespace + "/worksheet", target))
        }

        var writer = XMLWriter()
        writer.open("Relationships", [("xmlns", Fragments.packageRelationshipNamespace)])
        for relationship in relationships {
            writer.empty("Relationship", [
                ("Id", relationship.id),
                ("Type", relationship.type),
                ("Target", relationship.target),
            ])
        }
        writer.close("Relationships")
        return writer.data
    }

    private static func unusedID(_ used: inout Set<String>) -> String {
        var index = used.count + 1
        while used.contains("rId\(index)") { index += 1 }
        used.insert("rId\(index)")
        return "rId\(index)"
    }

    private static func packageRelationships() -> Data {
        var writer = XMLWriter()
        writer.open("Relationships", [("xmlns", Fragments.packageRelationshipNamespace)])
        writer.empty("Relationship", [
            ("Id", "rId1"),
            ("Type", Fragments.relationshipNamespace + "/officeDocument"),
            ("Target", "xl/workbook.xml"),
        ])
        writer.close("Relationships")
        return writer.data
    }

    private static func contentTypes(_ workbook: Workbook, existing: PackageParts) -> Data {
        var defaults: [(extension: String, type: String)] = []
        var overrides: [(part: String, type: String)] = []

        if let data = existing["[Content_Types].xml"], let root = try? XMLDocument.parse(data) {
            for node in root.elements(named: "Default") {
                guard let ext = node.attributes.attribute("Extension"),
                      let type = node.attributes.attribute("ContentType") else { continue }
                defaults.append((ext, type))
            }
            for node in root.elements(named: "Override") {
                guard let part = node.attributes.attribute("PartName"),
                      let type = node.attributes.attribute("ContentType") else { continue }
                // Sheet overrides are rebuilt below so deleted sheets drop out.
                if type == Fragments.worksheetContentType { continue }
                overrides.append((part, type))
            }
        }
        if defaults.isEmpty {
            defaults = [
                ("rels", "application/vnd.openxmlformats-package.relationships+xml"),
                ("xml", "application/xml"),
            ]
        }
        if !overrides.contains(where: { $0.part == "/xl/workbook.xml" }) {
            overrides.append(("/xl/workbook.xml",
                              "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"))
        }
        if !overrides.contains(where: { $0.type == Fragments.stylesContentType }) {
            overrides.append(("/xl/styles.xml", Fragments.stylesContentType))
        }
        if !overrides.contains(where: { $0.type == Fragments.sharedStringsContentType }) {
            overrides.append(("/xl/sharedStrings.xml", Fragments.sharedStringsContentType))
        }
        for sheet in workbook.sheets {
            overrides.append(("/" + sheet.partName, Fragments.worksheetContentType))
        }

        var writer = XMLWriter()
        writer.open("Types", [("xmlns", Fragments.contentTypesNamespace)])
        for entry in defaults {
            writer.empty("Default", [("Extension", entry.extension), ("ContentType", entry.type)])
        }
        for entry in overrides {
            writer.empty("Override", [("PartName", entry.part), ("ContentType", entry.type)])
        }
        writer.close("Types")
        return writer.data
    }
}
