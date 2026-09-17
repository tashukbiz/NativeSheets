import AppKit
import XLSXKit

protocol SpreadsheetDocumentObserver: AnyObject {
    /// The workbook changed: cells, layout, or the set of sheets.
    func documentDidChange(_ document: SpreadsheetDocument, reloadingSheets: Bool)
    func document(_ document: SpreadsheetDocument, didReport issues: [RecalculationIssue])
}

/// The open workbook.
///
/// Every mutation goes through `perform`, which snapshots the workbook, applies
/// the change, recalculates what the change affects and registers the inverse
/// with the undo manager. Workbook is a value type, so a snapshot costs a
/// retain rather than a deep copy.
/// The Objective-C name is pinned so that `CFBundleDocumentTypes` in
/// Info.plist does not have to spell out the Swift module.
@objc(SpreadsheetDocument)
final class SpreadsheetDocument: NSDocument {
    private(set) var workbook = Workbook()
    private(set) var activeSheetIndex = 0
    weak var observer: SpreadsheetDocumentObserver?

    private struct State {
        var workbook: Workbook
        var activeSheetIndex: Int
    }

    var activeSheet: Worksheet { workbook.sheets[min(activeSheetIndex, workbook.sheets.count - 1)] }

    override init() {
        super.init()
        undoManager?.levelsOfUndo = 100
    }

    // MARK: - Files

    override class var autosavesInPlace: Bool { false }

    override nonisolated static var readableTypes: [String] { ["org.openxmlformats.spreadsheetml.sheet"] }
    override nonisolated static var writableTypes: [String] { ["org.openxmlformats.spreadsheetml.sheet"] }

    override func read(from data: Data, ofType typeName: String) throws {
        workbook = try XLSXReader.read(data: data)
        activeSheetIndex = workbook.activeSheetIndex
    }

    override func data(ofType typeName: String) throws -> Data {
        var snapshot = workbook
        snapshot.activeSheetIndex = activeSheetIndex
        return try XLSXWriter.data(for: snapshot)
    }

    override func makeWindowControllers() {
        addWindowController(SpreadsheetWindowController())
    }

    /// Loads a workbook directly, for tests and for the blank document a new
    /// window starts with.
    func adopt(_ workbook: Workbook) {
        self.workbook = workbook
        activeSheetIndex = min(workbook.activeSheetIndex, workbook.sheets.count - 1)
        observer?.documentDidChange(self, reloadingSheets: true)
    }

    // MARK: - Mutation

    /// Applies a change and makes it undoable.
    ///
    /// `changedCells` limits the recalculation to what those cells feed; pass
    /// nil after a structural change, where everything may have moved.
    func perform(_ actionName: String,
                 changedCells: [(sheetIndex: Int, address: CellAddress)]? = nil,
                 reloadingSheets: Bool = false,
                 _ body: (inout Workbook) -> Void) {
        let previous = State(workbook: workbook, activeSheetIndex: activeSheetIndex)
        body(&workbook)

        let issues: [RecalculationIssue]
        if let changedCells {
            issues = Recalculator.recalculate(&workbook, changedCells: changedCells)
        } else {
            issues = Recalculator.recalculate(&workbook)
        }
        activeSheetIndex = min(activeSheetIndex, workbook.sheets.count - 1)

        registerUndo(of: previous, actionName: actionName, reloadingSheets: reloadingSheets)
        updateChangeCount(.changeDone)
        observer?.documentDidChange(self, reloadingSheets: reloadingSheets)
        if !issues.isEmpty { observer?.document(self, didReport: issues) }
    }

    /// Recomputes every formula, for when a stale cached value is suspected.
    func recalculateEverything() {
        let issues = Recalculator.recalculate(&workbook)
        observer?.documentDidChange(self, reloadingSheets: false)
        observer?.document(self, didReport: issues)
    }

    func selectSheet(at index: Int) {
        guard workbook.sheets.indices.contains(index), index != activeSheetIndex else { return }
        activeSheetIndex = index
        observer?.documentDidChange(self, reloadingSheets: true)
    }

    private func registerUndo(of state: State, actionName: String, reloadingSheets: Bool) {
        undoManager?.setActionName(actionName)
        undoManager?.registerUndo(withTarget: self) { document in
            document.restore(state, actionName: actionName, reloadingSheets: reloadingSheets)
        }
    }

    /// Swapping state and re-registering the opposite makes undo and redo the
    /// same operation.
    private func restore(_ state: State, actionName: String, reloadingSheets: Bool) {
        let current = State(workbook: workbook, activeSheetIndex: activeSheetIndex)
        workbook = state.workbook
        activeSheetIndex = min(state.activeSheetIndex, workbook.sheets.count - 1)

        registerUndo(of: current, actionName: actionName, reloadingSheets: reloadingSheets)
        updateChangeCount(.changeDone)
        observer?.documentDidChange(self, reloadingSheets: true)
    }
}
