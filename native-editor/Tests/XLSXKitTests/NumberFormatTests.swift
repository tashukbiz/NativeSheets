import XCTest
@testable import XLSXKit

final class NumberFormatTests: XCTestCase {
    private func format(_ code: String, _ value: Double) -> String {
        NumberFormat(code: code).string(for: .number(value)).text
    }

    func testGeneral() {
        XCTAssertEqual(format("General", 1200), "1200")
        XCTAssertEqual(format("General", 0.5), "0.5")
        XCTAssertEqual(format("General", -3.25), "-3.25")
    }

    func testGroupingAndDecimals() {
        XCTAssertEqual(format("#,##0.00", 1234567.891), "1,234,567.89")
        XCTAssertEqual(format("#,##0", 1234.6), "1,235")
        XCTAssertEqual(format("0.00", 3.1), "3.10")
        XCTAssertEqual(format("0", 0.4), "0")
        XCTAssertEqual(format("#,##0.##", 1234.5), "1,234.5")
        XCTAssertEqual(format("#,##0.##", 1234.0), "1,234")
    }

    func testMinimumIntegerDigits() {
        XCTAssertEqual(format("00000", 42), "00042")
        XCTAssertEqual(format("#.##", 0.25), ".25")
    }

    func testPercent() {
        XCTAssertEqual(format("0%", 0.256), "26%")
        XCTAssertEqual(format("0.0%", 0.256), "25.6%")
    }

    func testCurrencyAndLiterals() {
        XCTAssertEqual(format("\"$\"#,##0.00", 1234.5), "$1,234.50")
        XCTAssertEqual(format("#,##0 \"units\"", 1500), "1,500 units")
        XCTAssertEqual(format("\\$0.00", 5), "$5.00")
    }

    func testThousandsScaling() {
        XCTAssertEqual(format("0.0,", 15400), "15.4")
        XCTAssertEqual(format("0.0,,", 15_400_000), "15.4")
    }

    func testNegativeAndZeroSections() {
        let code = "#,##0.00;[Red](#,##0.00);\"-\""
        XCTAssertEqual(format(code, 1200), "1,200.00")
        XCTAssertEqual(format(code, -1200), "(1,200.00)")
        XCTAssertEqual(format(code, 0), "-")
        XCTAssertEqual(NumberFormat(code: code).string(for: .number(-5)).colorRGB, "FFFF0000")
    }

    func testTextSection() {
        let result = NumberFormat(code: "0.00;;;\"[\"@\"]\"").string(for: .text("note"))
        XCTAssertEqual(result.text, "[note]")
        XCTAssertEqual(NumberFormat(code: "0.00").string(for: .text("plain")).text, "plain")
    }

    func testDates() {
        // 46281 is 16 September 2026.
        XCTAssertEqual(format("dd mmm yy", 46281), "16 Sep 26")
        XCTAssertEqual(format("dd mmm yyyy", 46281), "16 Sep 2026")
        XCTAssertEqual(format("yyyy-mm-dd", 46281), "2026-09-16")
        XCTAssertEqual(format("mmmm d, yyyy", 46281), "September 16, 2026")
        XCTAssertEqual(format("dddd", 46281), "Wednesday")
    }

    func testDateBeforeTheLeapYearBug() {
        XCTAssertEqual(format("yyyy-mm-dd", 1), "1900-01-01")
        XCTAssertEqual(format("yyyy-mm-dd", 59), "1900-02-28")
        XCTAssertEqual(format("yyyy-mm-dd", 61), "1900-03-01")
    }

    func testTimes() {
        XCTAssertEqual(format("hh:mm", 46281.5), "12:00")
        XCTAssertEqual(format("h:mm AM/PM", 46281.5), "12:00 PM")
        XCTAssertEqual(format("h:mm AM/PM", 46281.25), "6:00 AM")
        XCTAssertEqual(format("hh:mm:ss", 46281.75), "18:00:00")
        XCTAssertEqual(format("dd mmm yy hh:mm", 46281.5), "16 Sep 26 12:00")
    }

    func testElapsedTime() {
        XCTAssertEqual(format("[h]:mm", 1.5), "36:00")
    }

    func testMinutesVersusMonths() {
        XCTAssertEqual(format("mm", 46281.5), "09", "a lone mm is months")
        XCTAssertEqual(format("hh:mm", 46281.5), "12:00", "mm after an hour is minutes")
        XCTAssertEqual(format("mm:ss", 46281.5), "00:00", "mm before seconds is minutes")
    }

    func testNonNumericValues() {
        XCTAssertEqual(NumberFormat(code: "0.00").string(for: .empty).text, "")
        XCTAssertEqual(NumberFormat(code: "0.00").string(for: .boolean(true)).text, "TRUE")
        XCTAssertEqual(NumberFormat(code: "0.00").string(for: .error("#N/A")).text, "#N/A")
    }

    func testRecognizesDateFormats() {
        XCTAssertTrue(NumberFormat(code: "dd mmm yy").isDateFormat)
        XCTAssertTrue(NumberFormat(code: "hh:mm").isDateFormat)
        XCTAssertFalse(NumberFormat(code: "#,##0.00").isDateFormat)
        XCTAssertFalse(NumberFormat(code: "General").isDateFormat)
    }

    func testRoundTripsASerialThroughDate() {
        let serial = 46281.625
        XCTAssertEqual(ExcelDate.serial(from: ExcelDate.date(from: serial)), serial, accuracy: 1e-9)
    }
}
