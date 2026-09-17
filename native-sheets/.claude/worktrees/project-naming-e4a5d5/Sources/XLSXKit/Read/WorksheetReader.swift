import Foundation

/// Streams one worksheet part into a `Worksheet`.
///
/// Sheets are the only part that can reach tens of megabytes, so cells are
/// built straight from parse events. Top-level sections the editor does not
/// model are collected into trees and stored as text for the writer.
final class WorksheetReader: NSObject, XMLParserDelegate {
    private var sheet: Worksheet
    private let sharedStrings: [String]

    private var path: [String] = []
    private var capture: XMLNodeBuilder?
    private var captureDepth = 0

    private var rowIndex = 0
    private var row = Row()
    private var cellAddress = CellAddress(row: 1, column: 1)
    private var cell = Cell()
    private var cellType = "n"
    private var text = ""
    private var textTarget: TextTarget?

    /// Excel writes a repeated formula once, on a master cell, and points the
    /// rest of the block at it by index. Both sides are collected here and
    /// expanded once the sheet is parsed.
    private var sharedMasters: [Int: (address: CellAddress, formula: String)] = [:]
    private var sharedFollowers: [(address: CellAddress, index: Int)] = []
    private var shareIndex: Int?

    private enum TextTarget { case value, formula, inlineString }

    init(sheet: Worksheet, sharedStrings: [String]) {
        self.sheet = sheet
        self.sharedStrings = sharedStrings
    }

    static func read(_ data: Data, into sheet: Worksheet, sharedStrings: [String]) throws -> Worksheet {
        let reader = WorksheetReader(sheet: sheet, sharedStrings: sharedStrings)
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = false
        parser.delegate = reader
        guard parser.parse() else {
            throw XLSXError.malformedXML(parser.parserError?.localizedDescription ?? "worksheet")
        }
        reader.expandSharedFormulas()
        return reader.sheet
    }

    // MARK: - Parse events

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        let qualified = qualifiedName ?? name
        if let capture {
            capture.start(qualified, attributes)
            captureDepth += 1
            return
        }

        let local = localName(qualified)
        path.append(local)

        switch path.count {
        case 1:
            sheet.namespacePrefix = namespacePrefix(qualified)
        case 2:
            startSection(local, qualified, attributes)
        default:
            startNested(local, attributes)
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capture != nil {
            capture?.text(string)
        } else if textTarget != nil {
            text += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
                qualifiedName: String?) {
        if let capture {
            capture.end()
            captureDepth -= 1
            if captureDepth == 0, let root = capture.root {
                sheet.preserved[localName(root.name)] = root.serialized()
                self.capture = nil
            }
            return
        }

        let local = localName(qualifiedName ?? name)
        defer { if !path.isEmpty { path.removeLast() } }

        switch local {
        case "row":
            if !row.isDefault || !row.cells.isEmpty { sheet.rows[rowIndex] = row }
            row = Row()
        case "c":
            finishCell()
        case "v", "f", "t":
            finishText(local)
        default:
            break
        }
    }

    // MARK: - Sections

    private func startSection(_ local: String, _ qualified: String, _ attributes: [String: String]) {
        switch local {
        case "sheetData", "cols", "mergeCells", "dimension":
            break
        case "sheetPr", "sheetViews":
            // Modelled for display but also kept whole: the writer patches the
            // original fragment rather than regenerating it, so zoom levels,
            // outline properties and selections survive.
            beginCapture(qualified, attributes)
        case "sheetFormatPr":
            if let height = attributes.doubleAttribute("defaultRowHeight") { sheet.defaultRowHeight = height }
            if let width = attributes.doubleAttribute("defaultColWidth") { sheet.defaultColumnWidth = width }
        default:
            beginCapture(qualified, attributes)
        }
    }

    private func startNested(_ local: String, _ attributes: [String: String]) {
        switch local {
        case "col":
            guard let first = attributes.intAttribute("min"), let last = attributes.intAttribute("max") else { return }
            sheet.columns.append(ColumnSpan(
                first: first,
                last: last,
                width: attributes.boolAttribute("customWidth", default: attributes.attribute("width") != nil)
                    ? attributes.doubleAttribute("width") : nil,
                styleIndex: attributes.intAttribute("style"),
                hidden: attributes.boolAttribute("hidden", default: false)
            ))
        case "row":
            rowIndex = attributes.intAttribute("r") ?? (rowIndex + 1)
            row = Row()
            row.height = attributes.doubleAttribute("ht")
            row.styleIndex = attributes.boolAttribute("customFormat", default: attributes.attribute("s") != nil)
                ? attributes.intAttribute("s") : nil
            row.hidden = attributes.boolAttribute("hidden", default: false)
        case "c":
            if let reference = attributes.attribute("r"), let address = CellAddress(a1: reference) {
                cellAddress = address
            } else {
                cellAddress = CellAddress(row: rowIndex, column: cellAddress.column + 1)
            }
            cell = Cell(styleIndex: attributes.intAttribute("s") ?? 0)
            cellType = attributes.attribute("t") ?? "n"
        case "v":
            text = ""
            textTarget = .value
        case "f":
            text = ""
            textTarget = .formula
            shareIndex = attributes.attribute("t") == "shared" ? attributes.intAttribute("si") : nil
        case "t" where path.contains("is"):
            text = ""
            textTarget = .inlineString
        case "mergeCell":
            if let reference = attributes.attribute("ref"), let range = CellRange(a1: reference) {
                sheet.merges.append(range)
            }
        default:
            break
        }
    }

    private func beginCapture(_ qualified: String, _ attributes: [String: String]) {
        let builder = XMLNodeBuilder()
        builder.start(qualified, attributes)
        capture = builder
        captureDepth = 1
        path.removeLast()
    }

    // MARK: - Cells

    private func finishText(_ local: String) {
        guard let target = textTarget else { return }
        switch target {
        case .formula:
            cell.formula = text.isEmpty ? nil : text
        case .inlineString:
            cell.value = .text(text)
        case .value:
            cell.value = value(from: text)
        }
        textTarget = nil
        text = ""
    }

    private func value(from raw: String) -> CellValue {
        switch cellType {
        case "s":
            guard let index = Int(raw), sharedStrings.indices.contains(index) else { return .text(raw) }
            return .text(sharedStrings[index])
        case "b":
            return .boolean(raw == "1" || raw.lowercased() == "true")
        case "e":
            return .error(raw)
        // `str` is a formula's cached string result, but producers also use it
        // for plain text cells; the sample workbook stores every label that way.
        case "str", "inlineStr", "d":
            return .text(raw)
        default:
            return Double(raw).map { CellValue.number($0) } ?? .text(raw)
        }
    }

    private func finishCell() {
        if let index = shareIndex {
            if let formula = cell.formula {
                sharedMasters[index] = (cellAddress, formula)
            } else {
                sharedFollowers.append((cellAddress, index))
            }
        }
        if !cell.isDefault {
            row.cells[cellAddress.column] = cell
        }
        cell = Cell()
        shareIndex = nil
    }

    private func expandSharedFormulas() {
        for follower in sharedFollowers {
            guard let master = sharedMasters[follower.index] else { continue }
            sheet[follower.address].formula = FormulaTranslator.shift(
                master.formula,
                rowDelta: follower.address.row - master.address.row,
                columnDelta: follower.address.column - master.address.column
            )
        }
    }
}
