import Foundation
@testable import XLSXKit

/// Builds workbooks in memory so the suite does not depend on checked-in
/// binaries, and can produce the same workbook under either namespace-prefix
/// convention.
enum Fixtures {
    static let mainNamespace = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    static let relationshipNamespace = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"

    static func sampleWorkbook(prefixed: Bool = false) -> Data {
        ZipWriter.archive([
            ZipWriter.Entry(name: "[Content_Types].xml", data: Data(contentTypes.utf8)),
            ZipWriter.Entry(name: "_rels/.rels", data: Data(packageRelationships.utf8)),
            ZipWriter.Entry(name: "xl/workbook.xml", data: Data(render(workbookPart, prefixed).utf8)),
            ZipWriter.Entry(name: "xl/_rels/workbook.xml.rels", data: Data(workbookRelationships.utf8)),
            ZipWriter.Entry(name: "xl/sharedStrings.xml", data: Data(render(sharedStringsPart, prefixed).utf8)),
            ZipWriter.Entry(name: "xl/styles.xml", data: Data(render(stylesPart, prefixed).utf8)),
            ZipWriter.Entry(name: "xl/theme/theme1.xml", data: Data("<theme/>".utf8)),
            ZipWriter.Entry(name: "xl/worksheets/sheet1.xml", data: Data(render(summarySheet, prefixed).utf8)),
            ZipWriter.Entry(name: "xl/worksheets/sheet2.xml", data: Data(render(dataSheet, prefixed).utf8)),
            ZipWriter.Entry(name: "xl/worksheets/sheet3.xml", data: Data(render(notesSheet, prefixed).utf8)),
        ])
    }

    /// `~` marks an element name. Rendering either prefixes them all, as the
    /// sample tracker does, or relies on a default namespace, as Excel does.
    private static func render(_ template: String, _ prefixed: Bool) -> String {
        let body = template.replacingOccurrences(of: "~", with: prefixed ? "x:" : "")
        let declaration = prefixed
            ? "xmlns:x=\"\(mainNamespace)\""
            : "xmlns=\"\(mainNamespace)\""
        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
            + body.replacingOccurrences(of: "@NS@", with: declaration)
    }

    private static let contentTypes = """
    <?xml version="1.0" encoding="UTF-8"?>\
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\
    <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\
    <Default Extension="xml" ContentType="application/xml"/>\
    <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>\
    <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>\
    <Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>\
    <Override PartName="/xl/worksheets/sheet3.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>\
    <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>\
    <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>\
    <Override PartName="/xl/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>\
    </Types>
    """

    private static let packageRelationships = """
    <?xml version="1.0" encoding="UTF-8"?>\
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
    <Relationship Id="rId1" Type="\(relationshipNamespace)/officeDocument" Target="xl/workbook.xml"/>\
    </Relationships>
    """

    private static let workbookRelationships = """
    <?xml version="1.0" encoding="UTF-8"?>\
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
    <Relationship Id="rId1" Type="\(relationshipNamespace)/worksheet" Target="worksheets/sheet1.xml"/>\
    <Relationship Id="rId2" Type="\(relationshipNamespace)/worksheet" Target="worksheets/sheet2.xml"/>\
    <Relationship Id="rId3" Type="\(relationshipNamespace)/worksheet" Target="worksheets/sheet3.xml"/>\
    <Relationship Id="rId4" Type="\(relationshipNamespace)/styles" Target="styles.xml"/>\
    <Relationship Id="rId5" Type="\(relationshipNamespace)/sharedStrings" Target="sharedStrings.xml"/>\
    <Relationship Id="rId6" Type="\(relationshipNamespace)/theme" Target="theme/theme1.xml"/>\
    </Relationships>
    """

    private static let workbookPart = """
    <~workbook @NS@ xmlns:r="\(relationshipNamespace)">\
    <~bookViews><~workbookView activeTab="1"/></~bookViews>\
    <~sheets>\
    <~sheet name="Summary" sheetId="1" r:id="rId1"/>\
    <~sheet name="Data" sheetId="2" r:id="rId2"/>\
    <~sheet name="Notes" sheetId="3" r:id="rId3"/>\
    </~sheets>\
    <~definedNames><~definedName name="Threshold">Data!$B$2</~definedName></~definedNames>\
    </~workbook>
    """

    private static let sharedStringsPart = """
    <~sst @NS@ count="2" uniqueCount="2">\
    <~si><~t>Quarterly report</~t></~si>\
    <~si><~r><~t>Rich </~t></~r><~r><~t>text</~t></~r></~si>\
    </~sst>
    """

    private static let stylesPart = """
    <~styleSheet @NS@>\
    <~numFmts count="1"><~numFmt numFmtId="164" formatCode="#,##0.00"/></~numFmts>\
    <~fonts count="2">\
    <~font><~sz val="11"/><~name val="Calibri"/></~font>\
    <~font><~b/><~sz val="12"/><~color rgb="FF1A2B3C"/><~name val="Helvetica"/></~font>\
    </~fonts>\
    <~fills count="3">\
    <~fill><~patternFill patternType="none"/></~fill>\
    <~fill><~patternFill patternType="gray125"/></~fill>\
    <~fill><~patternFill patternType="solid"><~fgColor rgb="FFEEEEEE"/></~patternFill></~fill>\
    </~fills>\
    <~borders count="2"><~border/>\
    <~border><~bottom style="thin"><~color rgb="FF999999"/></~bottom></~border></~borders>\
    <~cellStyleXfs count="1"><~xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></~cellStyleXfs>\
    <~cellXfs count="3">\
    <~xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>\
    <~xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyAlignment="1">\
    <~alignment horizontal="center" vertical="center" wrapText="1"/></~xf>\
    <~xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>\
    </~cellXfs>\
    <~tableStyles count="0" defaultTableStyle="TableStyleMedium2"/>\
    </~styleSheet>
    """

    private static let summarySheet = """
    <~worksheet @NS@><~sheetData>\
    <~row r="1"><~c r="A1" t="s"><~v>0</~v></~c></~row>\
    <~row r="2"><~c r="A2" t="s"><~v>1</~v></~c></~row>\
    </~sheetData></~worksheet>
    """

    private static let dataSheet = """
    <~worksheet @NS@>\
    <~sheetPr><~tabColor rgb="FF4472C4"/></~sheetPr>\
    <~sheetViews><~sheetView showGridLines="0" zoomScale="120" workbookViewId="0">\
    <~pane xSplit="1" ySplit="1" topLeftCell="B2" activePane="bottomRight" state="frozen"/>\
    </~sheetView></~sheetViews>\
    <~sheetFormatPr defaultRowHeight="15"/>\
    <~cols><~col min="1" max="1" width="24" customWidth="1"/>\
    <~col min="2" max="3" width="14" customWidth="1"/></~cols>\
    <~sheetData>\
    <~row r="1" ht="30" customHeight="1">\
    <~c r="A1" s="1" t="str"><~v>Region</~v></~c>\
    <~c r="B1" s="1" t="str"><~v>Amount</~v></~c>\
    <~c r="C1" s="1" t="str"><~v>Active</~v></~c>\
    </~row>\
    <~row r="2">\
    <~c r="A2" t="str"><~v>North</~v></~c>\
    <~c r="B2" s="2"><~v>1200</~v></~c>\
    <~c r="C2" t="b"><~v>1</~v></~c>\
    <~c r="D2"><~f t="shared" ref="D2:D3" si="0">B2*2</~f><~v>2400</~v></~c>\
    </~row>\
    <~row r="3">\
    <~c r="A3" t="str"><~v>South</~v></~c>\
    <~c r="B3" s="2"><~v>1900</~v></~c>\
    <~c r="C3" t="e"><~v>#DIV/0!</~v></~c>\
    <~c r="D3"><~f t="shared" si="0"/><~v>3800</~v></~c>\
    </~row>\
    <~row r="4"><~c r="B4" s="2"><~f>SUM(B2:B3)</~f><~v>3100</~v></~c></~row>\
    <~row r="6"><~c r="A6" t="str"><~v>Merged footer</~v></~c></~row>\
    </~sheetData>\
    <~autoFilter ref="A1:C3"/>\
    <~dataValidations count="1"><~dataValidation type="list" sqref="C1:C4">\
    <~formula1>"yes,no,maybe"</~formula1></~dataValidation></~dataValidations>\
    <~mergeCells count="1"><~mergeCell ref="A6:C6"/></~mergeCells>\
    <~pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/>\
    </~worksheet>
    """

    private static let notesSheet = """
    <~worksheet @NS@><~sheetData>\
    <~row r="1"><~c r="A1" t="inlineStr"><~is><~t>Inline note</~t></~is></~c></~row>\
    </~sheetData></~worksheet>
    """
}
