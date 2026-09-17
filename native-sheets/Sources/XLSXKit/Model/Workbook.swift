import Foundation

public enum XLSXError: Error, LocalizedError {
    case malformedXML(String)
    case missingPart(String)
    case noWorksheets
    case duplicateSheetName(String)
    case invalidSheetName(String)

    public var errorDescription: String? {
        switch self {
        case .malformedXML(let detail): return "The workbook contains invalid XML: \(detail)"
        case .missingPart(let name): return "The workbook is missing its \(name) part."
        case .noWorksheets: return "The workbook contains no sheets."
        case .duplicateSheetName(let name): return "A sheet named “\(name)” already exists."
        case .invalidSheetName(let name): return "“\(name)” is not a valid sheet name."
        }
    }
}

/// Every part of the opened package, by archive path.
///
/// The reader fills this with the original bytes so the writer can copy across
/// anything it does not regenerate.
public struct PackageParts: Sendable {
    public private(set) var parts: [String: Data] = [:]
    /// Original order, which OOXML expects to start with `[Content_Types].xml`.
    public private(set) var order: [String] = []

    public init() {}

    public subscript(path: String) -> Data? {
        get { parts[path] }
        set {
            if parts[path] == nil, newValue != nil { order.append(path) }
            if newValue == nil { order.removeAll { $0 == path } }
            parts[path] = newValue
        }
    }

    public func contains(_ path: String) -> Bool { parts[path] != nil }
}

/// A workbook: an ordered list of sheets plus the shared style table.
public struct Workbook: Sendable {
    public var sheets: [Worksheet]
    public var styles = WorkbookStyles()
    public var activeSheetIndex: Int = 0

    /// Untouched bytes of the package this workbook was read from, empty for a
    /// workbook created from scratch.
    var package = PackageParts()
    /// Workbook-level children the editor does not model (defined names,
    /// calculation properties, pivot caches).
    var preserved: [String: String] = [:]
    /// Relationship ids already used in `xl/_rels/workbook.xml.rels`.
    var usedRelationshipIDs: Set<String> = []
    /// Element prefix used by `xl/workbook.xml`, empty for a default namespace.
    var namespacePrefix: String = ""

    public init(sheets: [Worksheet]) {
        self.sheets = sheets
    }

    /// A new single-sheet workbook.
    public init() {
        var sheet = Worksheet(name: "Sheet1")
        sheet.partName = "xl/worksheets/sheet1.xml"
        sheet.relationshipID = "rId1"
        sheet.sheetID = 1
        self.sheets = [sheet]
        self.usedRelationshipIDs = ["rId1"]
    }

    public subscript(sheetName: String) -> Worksheet? {
        sheets.first { $0.name.caseInsensitiveCompare(sheetName) == .orderedSame }
    }

    public func index(ofSheet name: String) -> Int? {
        sheets.firstIndex { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    // MARK: - Sheet operations

    /// Sheet names may not exceed 31 characters, be empty, or contain
    /// `: \ / ? * [ ]`, and Excel refuses to open a file that breaks the rule.
    public static func isValidSheetName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.count <= 31 else { return false }
        return trimmed.rangeOfCharacter(from: CharacterSet(charactersIn: ":\\/?*[]")) == nil
    }

    public func uniqueSheetName(basedOn base: String = "Sheet") -> String {
        var candidate = base
        var suffix = 1
        while index(ofSheet: candidate) != nil {
            suffix += 1
            candidate = "\(base)\(suffix)"
        }
        return candidate
    }

    @discardableResult
    public mutating func insertSheet(named name: String, at position: Int) throws -> Int {
        guard Workbook.isValidSheetName(name) else { throw XLSXError.invalidSheetName(name) }
        guard index(ofSheet: name) == nil else { throw XLSXError.duplicateSheetName(name) }

        var sheet = Worksheet(name: name)
        sheet.sheetID = (sheets.map(\.sheetID).max() ?? 0) + 1
        sheet.partName = unusedPartName()
        sheet.relationshipID = unusedRelationshipID()
        usedRelationshipIDs.insert(sheet.relationshipID)

        let clamped = max(0, min(position, sheets.count))
        sheets.insert(sheet, at: clamped)
        return clamped
    }

    public mutating func removeSheet(at index: Int) throws {
        guard sheets.count > 1 else { throw XLSXError.noWorksheets }
        sheets.remove(at: index)
        activeSheetIndex = min(activeSheetIndex, sheets.count - 1)
    }

    public mutating func moveSheet(from source: Int, to destination: Int) {
        guard sheets.indices.contains(source) else { return }
        let sheet = sheets.remove(at: source)
        sheets.insert(sheet, at: max(0, min(destination, sheets.count)))
    }

    public mutating func renameSheet(at index: Int, to name: String) throws {
        guard Workbook.isValidSheetName(name) else { throw XLSXError.invalidSheetName(name) }
        if let existing = self.index(ofSheet: name), existing != index {
            throw XLSXError.duplicateSheetName(name)
        }
        sheets[index].name = name
    }

    /// Copies a sheet, including its cells and layout, under a fresh name.
    @discardableResult
    public mutating func duplicateSheet(at index: Int) throws -> Int {
        var copy = sheets[index]
        copy.name = uniqueSheetName(basedOn: sheets[index].name + " copy")
        copy.sheetID = (sheets.map(\.sheetID).max() ?? 0) + 1
        copy.partName = unusedPartName()
        copy.relationshipID = unusedRelationshipID()
        usedRelationshipIDs.insert(copy.relationshipID)
        // Sections carrying relationship ids (table parts, drawings) would
        // dangle against a part that has no relationships of its own.
        copy.preserved = copy.preserved.filter { !$0.value.contains(":id=") }
        sheets.insert(copy, at: index + 1)
        return index + 1
    }

    private func unusedPartName() -> String {
        var index = sheets.count + 1
        var candidate = "xl/worksheets/sheet\(index).xml"
        let taken = Set(sheets.map(\.partName))
        while taken.contains(candidate) || package.contains(candidate) {
            index += 1
            candidate = "xl/worksheets/sheet\(index).xml"
        }
        return candidate
    }

    private func unusedRelationshipID() -> String {
        var index = usedRelationshipIDs.count + sheets.count + 1
        var candidate = "rId\(index)"
        let taken = usedRelationshipIDs.union(sheets.map(\.relationshipID))
        while taken.contains(candidate) {
            index += 1
            candidate = "rId\(index)"
        }
        return candidate
    }
}
