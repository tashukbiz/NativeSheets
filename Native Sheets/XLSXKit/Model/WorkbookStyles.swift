import Foundation

/// The workbook's style part: number formats, fonts, fills, borders and the
/// `cellXfs` table that cells index into.
///
/// The parsed arrays drive rendering; the original XML tree is kept alongside
/// so that applying bold to one cell does not discard the parts of `styles.xml`
/// the editor has no model for.
public struct WorkbookStyles: Sendable {
    public struct Font: Hashable, Sendable {
        public var name: String = "Calibri"
        public var size: Double = 11
        public var bold = false
        public var italic = false
        public var underline = false
        public var strikethrough = false
        public var colorRGB: String?
    }

    public struct Fill: Hashable, Sendable {
        public var patternType: String?
        public var foregroundRGB: String?
        public var backgroundRGB: String?

        public var solidRGB: String? {
            patternType == "solid" ? foregroundRGB : nil
        }
    }

    public struct Edge: Hashable, Sendable {
        public var style: String
        public var colorRGB: String?
    }

    public struct Border: Hashable, Sendable {
        public var left: Edge?
        public var right: Edge?
        public var top: Edge?
        public var bottom: Edge?
    }

    public enum HorizontalAlignment: String, Hashable, Sendable {
        case general, left, center, right, fill, justify, centerContinuous, distributed
    }

    public enum VerticalAlignment: String, Hashable, Sendable {
        case top, center, bottom, justify, distributed
    }

    public struct Alignment: Hashable, Sendable {
        public var horizontal: HorizontalAlignment?
        public var vertical: VerticalAlignment?
        public var wrapText = false
    }

    public struct CellFormat: Hashable, Sendable {
        public var numberFormatID: Int = 0
        public var fontID: Int = 0
        public var fillID: Int = 0
        public var borderID: Int = 0
        public var alignment = Alignment()
    }

    public internal(set) var fonts: [Font] = [Font()]
    public internal(set) var fills: [Fill] = [Fill(patternType: "none"), Fill(patternType: "gray125")]
    public internal(set) var borders: [Border] = [Border()]
    public internal(set) var cellFormats: [CellFormat] = [CellFormat()]
    public internal(set) var customNumberFormats: [Int: String] = [:]

    /// Set once a style is added, so the writer knows to regenerate the part.
    internal private(set) var isModified = false

    /// Style sections the editor does not model (`cellStyles`, `dxfs`,
    /// `tableStyles`, theme colors), kept verbatim. The sample workbook styles
    /// its tables through `tableStyles`, which would otherwise be lost the
    /// first time a cell is made bold.
    var preserved: [String: String] = [:]
    /// Element prefix used by `xl/styles.xml`.
    var namespacePrefix: String = ""

    public init() {}

    // MARK: - Lookup

    public func format(at index: Int) -> CellFormat {
        cellFormats.indices.contains(index) ? cellFormats[index] : CellFormat()
    }

    public func font(at index: Int) -> Font {
        fonts.indices.contains(index) ? fonts[index] : Font()
    }

    public func fill(at index: Int) -> Fill {
        fills.indices.contains(index) ? fills[index] : Fill()
    }

    public func border(at index: Int) -> Border {
        borders.indices.contains(index) ? borders[index] : Border()
    }

    public func font(forStyle index: Int) -> Font { font(at: format(at: index).fontID) }
    public func fill(forStyle index: Int) -> Fill { fill(at: format(at: index).fillID) }
    public func border(forStyle index: Int) -> Border { border(at: format(at: index).borderID) }
    public func alignment(forStyle index: Int) -> Alignment { format(at: index).alignment }

    public func numberFormatCode(forStyle index: Int) -> String {
        numberFormatCode(id: format(at: index).numberFormatID)
    }

    public func numberFormatCode(id: Int) -> String {
        customNumberFormats[id] ?? WorkbookStyles.builtInNumberFormats[id] ?? "General"
    }

    // MARK: - Mutation

    /// Returns the index of a `cellXfs` entry matching `format`, adding one if
    /// no equivalent entry exists.
    public mutating func index(of format: CellFormat) -> Int {
        if let existing = cellFormats.firstIndex(of: format) { return existing }
        cellFormats.append(format)
        isModified = true
        return cellFormats.count - 1
    }

    public mutating func index(of font: Font) -> Int {
        if let existing = fonts.firstIndex(of: font) { return existing }
        fonts.append(font)
        isModified = true
        return fonts.count - 1
    }

    public mutating func index(of fill: Fill) -> Int {
        if let existing = fills.firstIndex(of: fill) { return existing }
        fills.append(fill)
        isModified = true
        return fills.count - 1
    }

    public mutating func index(of border: Border) -> Int {
        if let existing = borders.firstIndex(of: border) { return existing }
        borders.append(border)
        isModified = true
        return borders.count - 1
    }

    public mutating func numberFormatID(for code: String) -> Int {
        if code == "General" { return 0 }
        if let builtIn = WorkbookStyles.builtInNumberFormats.first(where: { $0.value == code }) { return builtIn.key }
        if let existing = customNumberFormats.first(where: { $0.value == code }) { return existing.key }
        let id = max(164, (customNumberFormats.keys.max() ?? 163) + 1)
        customNumberFormats[id] = code
        isModified = true
        return id
    }

    /// Applies a change on top of an existing style and returns the style index
    /// to store on the cell.
    public mutating func applying(_ change: StyleChange, to styleIndex: Int) -> Int {
        var format = self.format(at: styleIndex)
        switch change {
        case .bold(let on):
            var font = self.font(at: format.fontID)
            font.bold = on
            format.fontID = index(of: font)
        case .italic(let on):
            var font = self.font(at: format.fontID)
            font.italic = on
            format.fontID = index(of: font)
        case .underline(let on):
            var font = self.font(at: format.fontID)
            font.underline = on
            format.fontID = index(of: font)
        case .textColor(let rgb):
            var font = self.font(at: format.fontID)
            font.colorRGB = rgb
            format.fontID = index(of: font)
        case .backgroundColor(let rgb):
            let fill = rgb.map { Fill(patternType: "solid", foregroundRGB: $0, backgroundRGB: "FF000000") }
                ?? Fill(patternType: "none")
            format.fillID = index(of: fill)
        case .horizontalAlignment(let value):
            format.alignment.horizontal = value
        case .verticalAlignment(let value):
            format.alignment.vertical = value
        case .wrapText(let on):
            format.alignment.wrapText = on
        case .numberFormat(let code):
            format.numberFormatID = numberFormatID(for: code)
        }
        return index(of: format)
    }

    public enum StyleChange: Sendable {
        case bold(Bool)
        case italic(Bool)
        case underline(Bool)
        case textColor(String?)
        case backgroundColor(String?)
        case horizontalAlignment(HorizontalAlignment?)
        case verticalAlignment(VerticalAlignment?)
        case wrapText(Bool)
        case numberFormat(String)
    }

    // MARK: - Built-in number formats

    /// Format ids 0-49 are defined by the spec and never written into the file.
    static let builtInNumberFormats: [Int: String] = [
        0: "General", 1: "0", 2: "0.00", 3: "#,##0", 4: "#,##0.00",
        9: "0%", 10: "0.00%", 11: "0.00E+00", 12: "# ?/?", 13: "# ??/??",
        14: "mm-dd-yy", 15: "d-mmm-yy", 16: "d-mmm", 17: "mmm-yy",
        18: "h:mm AM/PM", 19: "h:mm:ss AM/PM", 20: "h:mm", 21: "h:mm:ss",
        22: "m/d/yy h:mm",
        37: "#,##0 ;(#,##0)", 38: "#,##0 ;[Red](#,##0)",
        39: "#,##0.00;(#,##0.00)", 40: "#,##0.00;[Red](#,##0.00)",
        45: "mm:ss", 46: "[h]:mm:ss", 47: "mmss.0", 48: "##0.0E+0", 49: "@",
    ]
}
