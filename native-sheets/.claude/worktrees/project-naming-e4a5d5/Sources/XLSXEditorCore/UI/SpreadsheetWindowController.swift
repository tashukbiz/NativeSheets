import AppKit

final class SpreadsheetWindowController: NSWindowController {
    private let controller = SpreadsheetViewController()

    convenience init() {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 1100, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.minSize = CGSize(width: 560, height: 360)
        window.tabbingMode = .automatic
        self.init(window: window)

        window.contentViewController = controller
        shouldCascadeWindows = true
        windowFrameAutosaveName = "SpreadsheetWindow"
    }

    override var document: AnyObject? {
        didSet { controller.document = document as? SpreadsheetDocument }
    }

    var spreadsheetController: SpreadsheetViewController { controller }
}
