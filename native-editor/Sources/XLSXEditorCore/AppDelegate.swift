import AppKit
import XLSXKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public override init() { super.init() }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.build()
        NSApp.activate(ignoringOtherApps: true)
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// The active window's controller, which is where the editing menu items go.
    static var currentController: SpreadsheetViewController? {
        (NSApp.keyWindow?.windowController as? SpreadsheetWindowController)?.spreadsheetController
    }

    static var currentDocument: SpreadsheetDocument? {
        NSDocumentController.shared.currentDocument as? SpreadsheetDocument
    }
}

extension AppDelegate: NSMenuItemValidation {
    /// Everything the app adds to the menus acts on a sheet, so none of it
    /// applies when no workbook is open.
    public func validateMenuItem(_ item: NSMenuItem) -> Bool {
        guard let action = item.action,
              action.description.hasSuffix(":"),
              responds(to: action) else { return true }
        return AppDelegate.currentController != nil
    }
}

/// Menu actions live on the app delegate so they reach whichever window is
/// frontmost through the responder chain.
extension AppDelegate {
    @objc func editCell(_ sender: Any?) { AppDelegate.currentController?.beginEditingActiveCell() }
    @objc func insertRows(_ sender: Any?) { AppDelegate.currentController?.insertRows() }
    @objc func deleteRows(_ sender: Any?) { AppDelegate.currentController?.deleteRows() }
    @objc func insertColumns(_ sender: Any?) { AppDelegate.currentController?.insertColumns() }
    @objc func deleteColumns(_ sender: Any?) { AppDelegate.currentController?.deleteColumns() }
    @objc func mergeCells(_ sender: Any?) { AppDelegate.currentController?.mergeSelection() }
    @objc func unmergeCells(_ sender: Any?) { AppDelegate.currentController?.unmergeSelection() }
    @objc func toggleFreeze(_ sender: Any?) { AppDelegate.currentController?.toggleFreeze() }
    @objc func addSheet(_ sender: Any?) { AppDelegate.currentController?.addSheet() }
    @objc func renameSheet(_ sender: Any?) { AppDelegate.currentController?.renameActiveSheet() }
    @objc func recalculate(_ sender: Any?) { AppDelegate.currentDocument?.recalculateEverything() }

    /// While a cell editor has focus, the clipboard belongs to the text being
    /// typed, not to the selected cells.
    private static var isEditingText: Bool {
        NSApp.keyWindow?.firstResponder is NSTextView
    }

    private static func forwardToTextEditor(_ selector: Selector, _ sender: Any?) -> Bool {
        guard isEditingText else { return false }
        return NSApp.sendAction(selector, to: nil, from: sender)
    }

    @objc func copyCells(_ sender: Any?) {
        guard !AppDelegate.forwardToTextEditor(#selector(NSText.copy(_:)), sender) else { return }
        AppDelegate.currentController?.copySelection()
    }

    @objc func cutCells(_ sender: Any?) {
        guard !AppDelegate.forwardToTextEditor(#selector(NSText.cut(_:)), sender) else { return }
        AppDelegate.currentController?.cutSelection()
    }

    @objc func pasteCells(_ sender: Any?) {
        guard !AppDelegate.forwardToTextEditor(#selector(NSText.paste(_:)), sender) else { return }
        AppDelegate.currentController?.paste()
    }

    @objc func toggleBold(_ sender: Any?) {
        guard let controller = AppDelegate.currentController else { return }
        controller.applyStyle(.bold(!controller.selectionHas(\.bold)), named: "Bold")
    }

    @objc func toggleItalic(_ sender: Any?) {
        guard let controller = AppDelegate.currentController else { return }
        controller.applyStyle(.italic(!controller.selectionHas(\.italic)), named: "Italic")
    }

    @objc func toggleUnderline(_ sender: Any?) {
        guard let controller = AppDelegate.currentController else { return }
        controller.applyStyle(.underline(!controller.selectionHas(\.underline)), named: "Underline")
    }

    @objc func alignLeft(_ sender: Any?) {
        AppDelegate.currentController?.applyStyle(.horizontalAlignment(.left), named: "Align Left")
    }

    @objc func alignCenter(_ sender: Any?) {
        AppDelegate.currentController?.applyStyle(.horizontalAlignment(.center), named: "Align Center")
    }

    @objc func alignRight(_ sender: Any?) {
        AppDelegate.currentController?.applyStyle(.horizontalAlignment(.right), named: "Align Right")
    }

    @objc func toggleWrapText(_ sender: Any?) {
        AppDelegate.currentController?.applyStyle(.wrapText(true), named: "Wrap Text")
    }

    @objc func applyNumberFormat(_ sender: Any?) {
        guard let item = sender as? NSMenuItem, let code = item.representedObject as? String else { return }
        AppDelegate.currentController?.applyStyle(.numberFormat(code), named: "Number Format")
    }
}
