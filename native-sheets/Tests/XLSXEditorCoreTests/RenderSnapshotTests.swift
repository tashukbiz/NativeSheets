import AppKit
import XCTest
@testable import XLSXEditorCore
@testable import XLSXKit

/// Renders sheets to PNG files for eyeballing the drawing code.
///
/// Skipped unless `XLSX_RENDER_SOURCE` points at a workbook, so the suite does
/// not depend on a file outside the repository.
final class RenderSnapshotTests: XCTestCase {
    func testRendersEverySheetOfTheGivenWorkbook() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let source = environment["XLSX_RENDER_SOURCE"] else {
            throw XCTSkip("set XLSX_RENDER_SOURCE to render a workbook")
        }
        let output = environment["XLSX_RENDER_OUTPUT"] ?? NSTemporaryDirectory()
        let workbook = try XLSXReader.read(contentsOf: URL(fileURLWithPath: source))

        for index in workbook.sheets.indices {
            let document = SpreadsheetDocument()
            document.adopt(workbook)
            document.selectSheet(at: index)

            let controller = SpreadsheetViewController()
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1280, height: 800),
                                  styleMask: [.titled, .resizable], backing: .buffered, defer: false)
            window.contentViewController = controller
            controller.document = document
            window.layoutIfNeeded()
            controller.view.displayIfNeeded()

            let name = workbook.sheets[index].name.replacingOccurrences(of: "/", with: "-")
            try render(controller, to: "\(output)/sheet-\(index)-\(name).png")

            // Scrolled, so the frozen bands have to stay put over moving
            // content and the selection must not paint over them.
            let grid = controller.gridViewForTesting
            grid.enclosingScrollView?.contentView.scroll(to: CGPoint(x: 520, y: 430))
            grid.enclosingScrollView?.reflectScrolledClipView(grid.enclosingScrollView!.contentView)
            if let reference = environment["XLSX_RENDER_SELECT"],
               let address = CellAddress(a1: reference) {
                grid.select(CellRange(address), scroll: true)
            }
            try render(controller, to: "\(output)/sheet-\(index)-\(name)-scrolled.png")
        }
    }

    private func render(_ controller: SpreadsheetViewController, to path: String) throws {
        let view = controller.view
        view.displayIfNeeded()
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
        print("rendered \(path)")
    }
}
