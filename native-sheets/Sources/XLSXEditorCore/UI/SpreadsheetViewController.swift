import AppKit
import XLSXKit

/// Wires the formula bar, grid and sheet tabs to the document.
final class SpreadsheetViewController: NSViewController {
    private let formulaBar = FormulaBar()
    private let gridView = GridView(frame: .zero)
    private let tabBar = SheetTabBar()
    private let statusLabel = NSTextField(labelWithString: "")
    private let scrollView = NSScrollView()

    var document: SpreadsheetDocument? {
        didSet {
            document?.observer = self
            reload(reloadingSheets: true)
        }
    }

    override func loadView() {
        let container = NSView(frame: CGRect(x: 0, y: 0, width: 1100, height: 700))

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.documentView = gridView
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        formulaBar.delegate = self
        formulaBar.translatesAutoresizingMaskIntoConstraints = false
        gridView.delegate = self
        tabBar.delegate = self
        tabBar.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        for subview in [formulaBar, separator, scrollView, tabBar, statusLabel] as [NSView] {
            container.addSubview(subview)
        }

        NSLayoutConstraint.activate([
            formulaBar.topAnchor.constraint(equalTo: container.topAnchor),
            formulaBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            formulaBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            separator.topAnchor.constraint(equalTo: formulaBar.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: separator.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: tabBar.topAnchor),

            tabBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: statusLabel.leadingAnchor, constant: -12),
            tabBar.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            statusLabel.centerYAnchor.constraint(equalTo: tabBar.centerYAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            statusLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 460),
        ])

        view = container
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(gridView)
    }

    // MARK: - Refresh

    private func reload(reloadingSheets: Bool) {
        guard let document else { return }
        gridView.show(document.activeSheet, styles: document.workbook.styles,
                      keepingSelection: !reloadingSheets)
        tabBar.show(sheets: document.workbook.sheets, selected: document.activeSheetIndex)
        updateFormulaBar()
        gridView.needsDisplay = true
    }

    private func updateFormulaBar() {
        guard let document else { return }
        let sheet = document.activeSheet
        let address = gridView.activeCell
        formulaBar.show(address: address, cell: sheet[address],
                        numberFormat: document.workbook.styles.numberFormatCode(forStyle: sheet[address].styleIndex),
                        selection: gridView.selection)
        updateStatus()
    }

    /// The running total a spreadsheet shows for the current selection.
    private func updateStatus() {
        guard let document else { return }
        let sheet = document.activeSheet
        var count = 0
        var numbers: [Double] = []
        // Walked rather than materialised: selecting a whole column would
        // otherwise build an array of every address in it.
        let selection = gridView.selection
        outer: for row in selection.rows {
            for column in selection.columns {
                guard count < 100_000 else { break outer }
                let value = sheet[row, column].value
                if !value.isEmpty { count += 1 }
                if case .number(let number) = value { numbers.append(number) }
            }
        }
        guard count > 0 else {
            statusLabel.stringValue = ""
            return
        }
        var parts = ["Count \(count)"]
        if !numbers.isEmpty {
            let sum = numbers.reduce(0, +)
            parts.append("Sum " + NumberFormat.general(sum))
            parts.append("Average " + NumberFormat.general(sum / Double(numbers.count)))
        }
        statusLabel.stringValue = parts.joined(separator: "   ")
    }

    private func report(_ message: String) {
        statusLabel.stringValue = message
    }

    // MARK: - Actions used by the menu

    var selectedRange: CellRange { gridView.selection }

    /// The grid, so tests can deliver events to it.
    var gridViewForTesting: GridView { gridView }

    func focusGrid() {
        view.window?.makeFirstResponder(gridView)
    }

    func beginEditingActiveCell() {
        gridView.beginEditing(at: gridView.activeCell)
    }

    func select(_ range: CellRange) {
        gridView.select(range)
    }

    func renameActiveSheet() {
        guard let document else { return }
        tabBar.beginRenaming(document.activeSheetIndex)
    }

    func applyStyle(_ change: WorkbookStyles.StyleChange, named name: String) {
        guard let document else { return }
        let range = gridView.selection
        let sheetIndex = document.activeSheetIndex
        document.perform(name) { workbook in
            for row in range.rows {
                for column in range.columns {
                    let address = CellAddress(row: row, column: column)
                    let cell = workbook.sheets[sheetIndex][address]
                    let styleIndex = workbook.styles.applying(change, to: cell.styleIndex)
                    guard !(cell.isBlank && styleIndex == 0) else { continue }
                    workbook.sheets[sheetIndex][address].styleIndex = styleIndex
                }
            }
        }
    }

    /// Whether every cell in the selection already has the attribute, so the
    /// menu item can act as a toggle.
    func selectionHas(_ attribute: (WorkbookStyles.Font) -> Bool) -> Bool {
        guard let document else { return false }
        let sheet = document.activeSheet
        let selection = gridView.selection
        var checked = 0
        for row in selection.rows {
            for column in selection.columns {
                guard checked < 2000 else { return true }
                checked += 1
                guard attribute(document.workbook.styles.font(forStyle: sheet[row, column].styleIndex)) else {
                    return false
                }
            }
        }
        return checked > 0
    }

    func insertRows() {
        guard let document else { return }
        let range = gridView.selection
        let sheetIndex = document.activeSheetIndex
        document.perform("Insert Rows") {
            $0.insertRows(at: range.start.row, count: range.rowCount, inSheet: sheetIndex)
        }
    }

    func deleteRows() {
        guard let document else { return }
        let range = gridView.selection
        let sheetIndex = document.activeSheetIndex
        document.perform("Delete Rows") {
            $0.removeRows(at: range.start.row, count: range.rowCount, inSheet: sheetIndex)
        }
    }

    func insertColumns() {
        guard let document else { return }
        let range = gridView.selection
        let sheetIndex = document.activeSheetIndex
        document.perform("Insert Columns") {
            $0.insertColumns(at: range.start.column, count: range.columnCount, inSheet: sheetIndex)
        }
    }

    func deleteColumns() {
        guard let document else { return }
        let range = gridView.selection
        let sheetIndex = document.activeSheetIndex
        document.perform("Delete Columns") {
            $0.removeColumns(at: range.start.column, count: range.columnCount, inSheet: sheetIndex)
        }
    }

    func mergeSelection() {
        guard let document else { return }
        let range = gridView.selection
        let sheetIndex = document.activeSheetIndex
        guard range.start != range.end else { return }
        document.perform("Merge Cells") { workbook in
            // Anything already overlapping has to give way to the new merge.
            workbook.sheets[sheetIndex].merges.removeAll { $0.overlaps(range) }
            workbook.sheets[sheetIndex].merges.append(range)
        }
    }

    func unmergeSelection() {
        guard let document else { return }
        let range = gridView.selection
        let sheetIndex = document.activeSheetIndex
        document.perform("Unmerge Cells") { workbook in
            workbook.sheets[sheetIndex].merges.removeAll { $0.overlaps(range) }
        }
    }

    func toggleFreeze() {
        guard let document else { return }
        let active = gridView.activeCell
        let sheetIndex = document.activeSheetIndex
        document.perform("Freeze Panes") { workbook in
            if workbook.sheets[sheetIndex].freeze != nil {
                workbook.sheets[sheetIndex].freeze = nil
            } else {
                workbook.sheets[sheetIndex].freeze =
                    FreezePane(columns: active.column - 1, rows: active.row - 1)
            }
        }
    }

    func addSheet() {
        guard let document else { return }
        let position = document.activeSheetIndex + 1
        let name = document.workbook.uniqueSheetName()
        document.perform("Add Sheet", reloadingSheets: true) {
            try? $0.insertSheet(named: name, at: position)
        }
        document.selectSheet(at: position)
    }

    // MARK: - Clipboard

    func copySelection() {
        guard let document else { return }
        let sheet = document.activeSheet
        let range = gridView.selection
        let text = range.rows.map { row in
            range.columns.map { column -> String in
                let cell = sheet[CellAddress(row: row, column: column)]
                let code = document.workbook.styles.numberFormatCode(forStyle: cell.styleIndex)
                return CellInput.editingText(for: cell, numberFormat: code)
            }.joined(separator: "\t")
        }.joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func cutSelection() {
        copySelection()
        clear(gridView.selection)
    }

    func paste() {
        guard let document, let text = NSPasteboard.general.string(forType: .string) else { return }
        let origin = gridView.activeCell
        let sheetIndex = document.activeSheetIndex
        // Tab-separated rows are what every spreadsheet puts on the pasteboard.
        let rows = text.components(separatedBy: "\n").map { $0.components(separatedBy: "\t") }
        var changed: [(sheetIndex: Int, address: CellAddress)] = []

        document.perform("Paste") { workbook in
            for (rowOffset, columns) in rows.enumerated() {
                if rowOffset == rows.count - 1, columns == [""] { continue }
                for (columnOffset, value) in columns.enumerated() {
                    let address = CellAddress(row: origin.row + rowOffset,
                                              column: origin.column + columnOffset)
                    let parsed = CellInput.parse(value)
                    var cell = workbook.sheets[sheetIndex][address]
                    cell.value = parsed.value
                    cell.formula = parsed.formula
                    workbook.sheets[sheetIndex][address] = cell
                    changed.append((sheetIndex, address))
                }
            }
        }
        let endRow = origin.row + max(0, rows.count - 1)
        let endColumn = origin.column + max(0, (rows.map(\.count).max() ?? 1) - 1)
        gridView.select(CellRange(start: origin, end: CellAddress(row: endRow, column: endColumn)),
                        active: origin)
    }

    private func clear(_ range: CellRange) {
        guard let document else { return }
        let sheetIndex = document.activeSheetIndex
        let sheet = document.activeSheet
        var changed: [(sheetIndex: Int, address: CellAddress)] = []
        for row in range.rows {
            for column in range.columns where !sheet[row, column].isBlank {
                changed.append((sheetIndex, CellAddress(row: row, column: column)))
            }
        }
        guard !changed.isEmpty else { return }

        document.perform("Clear", changedCells: changed) { workbook in
            for entry in changed {
                // Formatting survives; only content is cleared.
                workbook.sheets[sheetIndex][entry.address].value = .empty
                workbook.sheets[sheetIndex][entry.address].formula = nil
            }
        }
    }
}

// MARK: - Document

extension SpreadsheetViewController: SpreadsheetDocumentObserver {
    func documentDidChange(_ document: SpreadsheetDocument, reloadingSheets: Bool) {
        reload(reloadingSheets: reloadingSheets)
    }

    func document(_ document: SpreadsheetDocument, didReport issues: [RecalculationIssue]) {
        guard let first = issues.first else { return }
        report(issues.count == 1 ? first.message : "\(first.message) (+\(issues.count - 1) more)")
    }
}

// MARK: - Grid

extension SpreadsheetViewController: GridViewDelegate {
    func gridView(_ grid: GridView, didChangeSelection selection: CellRange, active: CellAddress) {
        updateFormulaBar()
    }

    func gridView(_ grid: GridView, didBeginEditing address: CellAddress) {
        formulaBar.mirror(grid.editingText ?? "")
    }

    func gridView(_ grid: GridView, didCommit input: String, at address: CellAddress,
                  moving advance: GridView.Advance) {
        guard let document else { return }
        let sheetIndex = document.activeSheetIndex
        let existing = document.activeSheet[address]
        let parsed = CellInput.parse(input)

        let unchanged = parsed.value == existing.value && parsed.formula == existing.formula
        if !unchanged {
            document.perform("Edit \(address.a1)", changedCells: [(sheetIndex, address)]) { workbook in
                var cell = workbook.sheets[sheetIndex][address]
                cell.value = parsed.value
                cell.formula = parsed.formula
                // An implied format only applies where none was set.
                if let format = parsed.numberFormat,
                   workbook.styles.numberFormatCode(forStyle: cell.styleIndex) == "General" {
                    cell.styleIndex = workbook.styles.applying(.numberFormat(format), to: cell.styleIndex)
                }
                workbook.sheets[sheetIndex][address] = cell
            }
        }
        grid.advance(advance, from: address)
        updateFormulaBar()
    }

    func gridView(_ grid: GridView, didResizeColumn column: Int, to width: Double) {
        guard let document else { return }
        let sheetIndex = document.activeSheetIndex
        document.perform("Resize Column") { $0.sheets[sheetIndex].setWidth(width, forColumn: column) }
    }

    func gridView(_ grid: GridView, didResizeRow row: Int, to height: Double) {
        guard let document else { return }
        let sheetIndex = document.activeSheetIndex
        document.perform("Resize Row") { $0.sheets[sheetIndex].setHeight(height, forRow: row) }
    }

    func gridViewDidRequestClear(_ grid: GridView, range: CellRange) {
        clear(range)
    }
}

// MARK: - Formula bar

extension SpreadsheetViewController: FormulaBarDelegate {
    func formulaBar(_ bar: FormulaBar, didCommit text: String) {
        let address = gridView.activeCell
        gridView(gridView, didCommit: text, at: address, moving: .down)
        focusGrid()
    }

    func formulaBarDidCancel(_ bar: FormulaBar) {
        updateFormulaBar()
        focusGrid()
    }

    func formulaBar(_ bar: FormulaBar, didJumpTo address: CellAddress) {
        gridView.select(CellRange(address))
        focusGrid()
    }
}

// MARK: - Sheet tabs

extension SpreadsheetViewController: SheetTabBarDelegate {
    func sheetTabBar(_ bar: SheetTabBar, didSelect index: Int) {
        document?.selectSheet(at: index)
        focusGrid()
    }

    func sheetTabBar(_ bar: SheetTabBar, didRename index: Int, to name: String) {
        guard let document else { return }
        guard Workbook.isValidSheetName(name) else {
            report("A sheet name must be 1 to 31 characters and cannot contain : \\ / ? * [ ]")
            reload(reloadingSheets: true)
            return
        }
        if let existing = document.workbook.index(ofSheet: name), existing != index {
            report("A sheet named “\(name)” already exists")
            reload(reloadingSheets: true)
            return
        }
        document.perform("Rename Sheet", reloadingSheets: true) { try? $0.renameSheet(at: index, to: name) }
    }

    func sheetTabBar(_ bar: SheetTabBar, didMove index: Int, to destination: Int) {
        document?.perform("Move Sheet", reloadingSheets: true) { $0.moveSheet(from: index, to: destination) }
        document?.selectSheet(at: destination)
    }

    func sheetTabBarDidAddSheet(_ bar: SheetTabBar) {
        addSheet()
    }

    func sheetTabBar(_ bar: SheetTabBar, didRequestDelete index: Int) {
        guard let document, document.workbook.sheets.count > 1 else {
            report("A workbook must keep at least one sheet")
            return
        }
        let alert = NSAlert()
        alert.messageText = "Delete “\(document.workbook.sheets[index].name)”?"
        alert.informativeText = "The sheet and everything on it will be removed. This can be undone."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        document.perform("Delete Sheet", reloadingSheets: true) { try? $0.removeSheet(at: index) }
    }

    func sheetTabBar(_ bar: SheetTabBar, didRequestDuplicate index: Int) {
        document?.perform("Duplicate Sheet", reloadingSheets: true) { try? $0.duplicateSheet(at: index) }
        document?.selectSheet(at: index + 1)
    }
}
