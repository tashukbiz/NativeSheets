import AppKit
import XCTest
@testable import XLSXEditorCore
@testable import XLSXKit

final class SheetTabBarTests: XCTestCase {
    /// A sheet's colour fills its tab, so the label has to stay readable on
    /// anything from the sample's near-black navy to its pale grey.
    func testLabelContrastsWithTheTabColour() {
        let navy = NSColor(argbHex: "FF344767")!
        let grey = NSColor(argbHex: "FF94A3B8")!

        XCTAssertEqual(SheetTabBar.labelColor(on: navy, selected: false), .white)
        XCTAssertFalse(SheetTabBar.labelColor(on: grey, selected: false).isLight,
                       "a pale tab needs dark text")
    }

    func testAnUncolouredTabUsesTheStandardLabelColour() {
        XCTAssertEqual(SheetTabBar.labelColor(on: nil, selected: false), .secondaryLabelColor)
        XCTAssertEqual(SheetTabBar.labelColor(on: nil, selected: true), .labelColor)
    }

    /// The selected tab keeps the system label colour, because its background
    /// is the control background rather than the sheet's colour.
    func testTheSelectedTabIgnoresItsColourForTheLabel() {
        let navy = NSColor(argbHex: "FF344767")!
        XCTAssertEqual(SheetTabBar.labelColor(on: navy, selected: true), .labelColor)
    }

    func testLuminanceSplitsLightFromDark() {
        XCTAssertTrue(NSColor(argbHex: "FFFFFFFF")!.isLight)
        XCTAssertTrue(NSColor(argbHex: "FFFFF8E6")!.isLight)
        XCTAssertFalse(NSColor(argbHex: "FF000000")!.isLight)
        XCTAssertFalse(NSColor(argbHex: "FF344767")!.isLight)
    }
}
