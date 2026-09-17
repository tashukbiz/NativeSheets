import XCTest
@testable import XLSXKit

/// Reading the restriction that turns a cell into a dropdown.
final class DataValidationTests: XCTestCase {
    func testReadsAnInlineListFromTheFile() throws {
        let fragment = """
        <dataValidations count="2">\
        <dataValidation type="list" sqref="G8:G37">\
        <formula1>"Research incomplete,Draft ready,Contacted"</formula1></dataValidation>\
        <dataValidation type="whole" sqref="H8:H37"><formula1>0</formula1></dataValidation>\
        </dataValidations>
        """
        let validations = DataValidationReader.read(fragment)

        XCTAssertEqual(validations.count, 1, "only list validations are modelled")
        XCTAssertEqual(validations[0].values, ["Research incomplete", "Draft ready", "Contacted"])
        XCTAssertTrue(validations[0].covers(CellAddress(a1: "G20")!))
        XCTAssertFalse(validations[0].covers(CellAddress(a1: "H20")!))
    }

    func testReadsSeveralRangesInOneValidation() throws {
        let fragment = """
        <dataValidations><dataValidation type="list" sqref="B2:B5 D2:D5">\
        <formula1>"yes,no"</formula1></dataValidation></dataValidations>
        """
        let validation = try XCTUnwrap(DataValidationReader.read(fragment).first)
        XCTAssertTrue(validation.covers(CellAddress(a1: "D3")!))
        XCTAssertTrue(validation.covers(CellAddress(a1: "B3")!))
        XCTAssertFalse(validation.covers(CellAddress(a1: "C3")!))
    }

    /// A list that points at a range of cells is not resolved, so it must not
    /// be mistaken for a literal one.
    func testIgnoresAListDefinedByAReference() {
        let fragment = """
        <dataValidations><dataValidation type="list" sqref="B2:B5">\
        <formula1>$Z$1:$Z$9</formula1></dataValidation></dataValidations>
        """
        XCTAssertTrue(DataValidationReader.read(fragment).isEmpty)
    }

    func testValidationSurvivesAReadAndWrite() throws {
        let source = try XLSXReader.read(data: Fixtures.sampleWorkbook())
        XCTAssertEqual(source.sheets[1].listValidation(at: CellAddress(a1: "C2")!)?.values,
                       ["yes", "no", "maybe"])
        XCTAssertNil(source.sheets[1].listValidation(at: CellAddress(a1: "A2")!))

        let reloaded = try XLSXReader.read(data: XLSXWriter.data(for: source))
        XCTAssertEqual(reloaded.sheets[1].listValidation(at: CellAddress(a1: "C2")!)?.values,
                       ["yes", "no", "maybe"],
                       "the validation part must survive a save")
    }

}
