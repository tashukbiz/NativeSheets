import AppKit
import XLSXKit

protocol GridViewDelegate: AnyObject {
    func gridView(_ grid: GridView, didChangeSelection selection: CellRange, active: CellAddress)
    func gridView(_ grid: GridView, didCommit input: String, at address: CellAddress, moving: GridView.Advance)
    func gridView(_ grid: GridView, didResizeColumn column: Int, to width: Double)
    func gridView(_ grid: GridView, didResizeRow row: Int, to height: Double)
    func gridViewDidRequestClear(_ grid: GridView, range: CellRange)
    func gridView(_ grid: GridView, didBeginEditing address: CellAddress)
}

/// The spreadsheet canvas.
///
/// One view draws everything: headers, cells, frozen bands and the selection.
/// Only the visible rectangle is drawn, so scrolling costs the same on a
/// hundred-row sheet as on a hundred-thousand-row one.
final class GridView: NSView {
    enum Advance { case down, up, right, left, stay }

    weak var delegate: GridViewDelegate?

    private(set) var sheet = Worksheet(name: "")
    private var styles = WorkbookStyles()
    private var metrics: GridMetrics
    private(set) var selection = CellRange(CellAddress(row: 1, column: 1))
    private(set) var activeCell = CellAddress(row: 1, column: 1)
    /// The end a shift-arrow moves. Held apart from the selection because a
    /// range does not remember which of its corners the user is dragging.
    private var extensionCursor = CellAddress(row: 1, column: 1)

    private var editor: NSTextField?
    private var editingAddress: CellAddress?
    private var dragAnchor: CellAddress?
    private enum Resize { case column(Int, CGFloat), row(Int, CGFloat) }
    private var resizing: Resize?

    override init(frame: CGRect) {
        metrics = GridMetrics(sheet: Worksheet(name: ""))
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: - Content

    func show(_ sheet: Worksheet, styles: WorkbookStyles, keepingSelection: Bool = true) {
        self.sheet = sheet
        self.styles = styles
        rebuildMetrics()
        if !keepingSelection {
            selection = CellRange(CellAddress(row: 1, column: 1))
            activeCell = selection.start
            scrollToVisible(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        needsDisplay = true
    }

    private func rebuildMetrics() {
        // Leave room past the selection so arrowing off the used range works.
        metrics = GridMetrics(sheet: sheet,
                              extraRows: selection.end.row + 20,
                              extraColumns: selection.end.column + 5)
        let size = metrics.contentSize
        if frame.size != size { setFrameSize(size) }
    }

    func select(_ range: CellRange, active: CellAddress? = nil, scroll: Bool = true,
                cursor: CellAddress? = nil) {
        selection = range
        activeCell = active ?? range.start
        extensionCursor = cursor ?? activeCell
        rebuildMetrics()
        if scroll { scrollToActiveCell() }
        needsDisplay = true
        delegate?.gridView(self, didChangeSelection: selection, active: activeCell)
    }

    private func scrollToActiveCell() {
        var rect = metrics.rect(of: activeCell)
        // Keep the cell clear of the headers and any frozen bands.
        let freeze = sheet.freeze ?? FreezePane(columns: 0, rows: 0)
        let insetX = metrics.x(ofColumn: min(freeze.columns, metrics.columnCount) + 1)
        let insetY = metrics.y(ofRow: min(freeze.rows, metrics.rowCount) + 1)
        if activeCell.column > freeze.columns {
            rect.origin.x -= insetX
            rect.size.width += insetX
        }
        if activeCell.row > freeze.rows {
            rect.origin.y -= insetY
            rect.size.height += insetY
        }
        scrollToVisible(rect)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: CGRect) {
        GridRenderer(
            sheet: sheet, styles: styles, metrics: metrics,
            selection: selection, activeCell: activeCell,
            origin: visibleRect.origin
        ).draw(in: dirtyRect)
    }

    /// Headers and frozen bands are pinned to the scroll offset, so any scroll
    /// invalidates the whole visible area.
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        guard let clipView = superview as? NSClipView else { return }
        clipView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(clipViewDidScroll),
            name: NSView.boundsDidChangeNotification, object: clipView
        )
    }

    @objc private func clipViewDidScroll() {
        needsDisplay = true
        repositionEditor()
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        commitEditing(moving: .stay)
        window?.makeFirstResponder(self)

        if let resize = resizeTarget(at: point) {
            resizing = resize
            return
        }
        if validationButtonFrame()?.contains(point) == true {
            showValidationList()
            return
        }
        if event.clickCount >= 2, point.x > columnHeaderEdge, point.y > rowHeaderEdge {
            beginEditing(at: address(at: point))
            return
        }

        let inColumnHeader = point.y < rowHeaderEdge
        let inRowHeader = point.x < columnHeaderEdge

        if inColumnHeader && inRowHeader {
            select(CellRange(start: CellAddress(row: 1, column: 1),
                             end: CellAddress(row: metrics.rowCount, column: metrics.columnCount)),
                   active: CellAddress(row: 1, column: 1), scroll: false)
            return
        }
        if inColumnHeader {
            let column = columnIndex(at: point)
            dragAnchor = CellAddress(row: 1, column: column)
            select(CellRange(start: CellAddress(row: 1, column: column),
                             end: CellAddress(row: metrics.rowCount, column: column)),
                   active: CellAddress(row: 1, column: column), scroll: false)
            return
        }
        if inRowHeader {
            let row = rowIndex(at: point)
            dragAnchor = CellAddress(row: row, column: 1)
            select(CellRange(start: CellAddress(row: row, column: 1),
                             end: CellAddress(row: row, column: metrics.columnCount)),
                   active: CellAddress(row: row, column: 1), scroll: false)
            return
        }

        let target = address(at: point)
        if event.modifierFlags.contains(.shift) {
            select(CellRange(start: activeCell, end: target), active: activeCell, scroll: false)
        } else {
            dragAnchor = target
            select(CellRange(target), scroll: false)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        switch resizing {
        case .column(let column, let startX):
            let width = max(GridMetrics.minimumColumnWidth, point.x - startX)
            delegate?.gridView(self, didResizeColumn: column, to: GridMetrics.columnWidth(forPixels: width))
            return
        case .row(let row, let startY):
            let height = max(GridMetrics.minimumRowHeight, point.y - startY)
            delegate?.gridView(self, didResizeRow: row, to: GridMetrics.rowHeight(forPixels: height))
            return
        case nil:
            break
        }

        guard let anchor = dragAnchor else { return }
        autoscroll(with: event)
        let target = address(at: point)
        let extended = selection.rowCount == metrics.rowCount
            ? CellRange(start: CellAddress(row: 1, column: anchor.column),
                        end: CellAddress(row: metrics.rowCount, column: target.column))
            : CellRange(start: anchor, end: target)
        select(extended, active: anchor, scroll: false)
    }

    override func mouseUp(with event: NSEvent) {
        resizing = nil
        dragAnchor = nil
    }

    override func resetCursorRects() {
        // The resize cursor belongs on the dividers themselves, not the whole
        // header band.
        let visible = metrics.visibleRange(in: visibleRect)
        let handle = GridMetrics.resizeHandle

        for column in visible.columns where column <= metrics.columnCount {
            let x = metrics.x(ofColumn: column) + metrics.width(ofColumn: column)
            addCursorRect(CGRect(x: x - handle, y: visibleRect.minY,
                                 width: handle * 2, height: GridMetrics.headerHeight),
                          cursor: .resizeLeftRight)
        }
        for row in visible.rows where row <= metrics.rowCount {
            let y = metrics.y(ofRow: row) + metrics.height(ofRow: row)
            addCursorRect(CGRect(x: visibleRect.minX, y: y - handle,
                                 width: GridMetrics.headerWidth, height: handle * 2),
                          cursor: .resizeUpDown)
        }
    }

    private func resizeTarget(at point: CGPoint) -> Resize? {
        if point.y < rowHeaderEdge, point.x > columnHeaderEdge,
           let column = metrics.columnDivider(nearX: point.x) {
            return .column(column, metrics.x(ofColumn: column))
        }
        if point.x < columnHeaderEdge, point.y > rowHeaderEdge,
           let row = metrics.rowDivider(nearY: point.y) {
            return .row(row, metrics.y(ofRow: row))
        }
        return nil
    }

    // MARK: - Coordinates

    /// Frozen bands and headers are drawn at the scroll offset, so a click
    /// inside them maps to a different cell than its raw position suggests.
    private var columnHeaderEdge: CGFloat { visibleRect.minX + GridMetrics.headerWidth }
    private var rowHeaderEdge: CGFloat { visibleRect.minY + GridMetrics.headerHeight }

    private func address(at point: CGPoint) -> CellAddress {
        CellAddress(row: rowIndex(at: point), column: columnIndex(at: point))
    }

    private func columnIndex(at point: CGPoint) -> Int {
        let freeze = sheet.freeze?.columns ?? 0
        if freeze > 0, point.x < visibleRect.minX + metrics.x(ofColumn: freeze + 1) {
            return metrics.column(atX: point.x - visibleRect.minX)
        }
        return metrics.column(atX: point.x)
    }

    private func rowIndex(at point: CGPoint) -> Int {
        let freeze = sheet.freeze?.rows ?? 0
        if freeze > 0, point.y < visibleRect.minY + metrics.y(ofRow: freeze + 1) {
            return metrics.row(atY: point.y - visibleRect.minY)
        }
        return metrics.row(atY: point.y)
    }

    private func editorFrame(for address: CellAddress) -> CGRect {
        let merge = sheet.mergeContaining(address)
        var rect = metrics.rect(of: merge ?? CellRange(address))
        let freeze = sheet.freeze ?? FreezePane(columns: 0, rows: 0)
        if address.column <= freeze.columns { rect.origin.x += visibleRect.minX }
        if address.row <= freeze.rows { rect.origin.y += visibleRect.minY }
        return rect
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags
        guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else { return }

        switch Int(characters.unicodeScalars.first!.value) {
        case NSUpArrowFunctionKey: move(rows: -1, columns: 0, flags: flags); return
        case NSDownArrowFunctionKey:
            // Option-Down opens the list, as it does in a spreadsheet.
            if flags.contains(.option), validationButtonFrame() != nil {
                showValidationList()
                return
            }
            move(rows: 1, columns: 0, flags: flags)
            return
        case NSLeftArrowFunctionKey: move(rows: 0, columns: -1, flags: flags); return
        case NSRightArrowFunctionKey: move(rows: 0, columns: 1, flags: flags); return
        case NSPageUpFunctionKey: move(rows: -20, columns: 0, flags: flags); return
        case NSPageDownFunctionKey: move(rows: 20, columns: 0, flags: flags); return
        case NSHomeFunctionKey:
            select(CellRange(CellAddress(row: 1, column: 1)))
            return
        case NSDeleteFunctionKey, 0x7F:
            delegate?.gridViewDidRequestClear(self, range: selection)
            return
        case 0x0D, 0x03:  // Return, Enter
            beginEditing(at: activeCell)
            return
        case 0x09:  // Tab
            move(rows: 0, columns: flags.contains(.shift) ? -1 : 1, flags: [])
            return
        case 0x1B:  // Escape
            return
        case NSF2FunctionKey:
            beginEditing(at: activeCell)
            return
        default:
            break
        }

        // Anything printable starts an edit with that character.
        guard !flags.contains(.command), !flags.contains(.control),
              let scalar = characters.unicodeScalars.first, scalar.value >= 32 else {
            super.keyDown(with: event)
            return
        }
        beginEditing(at: activeCell, replacingWith: characters)
    }

    override func insertTab(_ sender: Any?) {
        move(rows: 0, columns: 1, flags: [])
    }

    private func move(rows: Int, columns: Int, flags: NSEvent.ModifierFlags) {
        let extending = flags.contains(.shift)
        let from = extending ? extensionCursor : activeCell
        let target: CellAddress
        if flags.contains(.command) {
            // Jump to the far edge of the run of data in that direction.
            target = edge(from: from, rows: rows, columns: columns)
        } else {
            target = CellAddress(row: max(1, from.row + rows), column: max(1, from.column + columns))
        }

        if extending {
            select(CellRange(start: activeCell, end: target), active: activeCell, cursor: target)
        } else {
            select(CellRange(target))
        }
    }

    /// Command-arrow behaviour: from inside a run of data, stop at its last
    /// filled cell; from an empty cell or the end of a run, skip the gap and
    /// land on the next filled cell.
    private func edge(from start: CellAddress, rows: Int, columns: Int) -> CellAddress {
        let extent = sheet.usedExtent
        let stepRow = rows == 0 ? 0 : (rows > 0 ? 1 : -1)
        let stepColumn = columns == 0 ? 0 : (columns > 0 ? 1 : -1)

        func step(_ address: CellAddress) -> CellAddress? {
            let next = CellAddress(row: address.row + stepRow, column: address.column + stepColumn)
            guard next.row >= 1, next.column >= 1,
                  next.row <= max(extent.rows, 1), next.column <= max(extent.columns, 1) else { return nil }
            return next
        }

        var current = start
        guard let first = step(current) else { return current }

        if !sheet[first].isBlank {
            current = first
            while let next = step(current), !sheet[next].isBlank { current = next }
            return current
        }

        current = first
        while sheet[current].isBlank {
            guard let next = step(current) else { return current }
            current = next
        }
        return current
    }

    // MARK: - Editing

    // MARK: - Data validation

    /// The dropdown button on the active cell, when it is restricted to a list.
    func validationButtonFrame() -> CGRect? {
        guard sheet.listValidation(at: mergeAnchor(activeCell)) != nil else { return nil }
        return GridRenderer.validationButtonRect(editorFrame(for: mergeAnchor(activeCell)))
    }

    private func mergeAnchor(_ address: CellAddress) -> CellAddress {
        sheet.mergeContaining(address)?.start ?? address
    }

    /// Offers the allowed values as a menu, the way a spreadsheet does for a
    /// cell restricted to a list.
    func showValidationList() {
        guard let menu = validationMenu() else { return }
        commitEditing(moving: .stay)
        let frame = editorFrame(for: mergeAnchor(activeCell))
        menu.popUp(positioning: nil, at: CGPoint(x: frame.minX, y: frame.maxY), in: self)
    }

    /// The allowed values for the active cell, as a menu.
    func validationMenu() -> NSMenu? {
        let address = mergeAnchor(activeCell)
        guard let validation = sheet.listValidation(at: address) else { return nil }

        let menu = NSMenu()
        let current = sheet[address].value.textValue
        for value in validation.values {
            let item = menu.addItem(withTitle: value, action: #selector(chooseValidationValue(_:)),
                                    keyEquivalent: "")
            item.target = self
            item.representedObject = value
            item.state = value == current ? .on : .off
        }
        menu.addItem(.separator())
        let clear = menu.addItem(withTitle: "Clear", action: #selector(chooseValidationValue(_:)),
                                 keyEquivalent: "")
        clear.target = self
        clear.representedObject = ""
        return menu
    }

    @objc func chooseValidationValue(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String else { return }
        delegate?.gridView(self, didCommit: value, at: mergeAnchor(activeCell), moving: .stay)
    }

    func beginEditing(at address: CellAddress, replacingWith seed: String? = nil) {
        commitEditing(moving: .stay)
        let anchor = sheet.mergeContaining(address)?.start ?? address

        let field = NSTextField(frame: editorFrame(for: anchor))
        field.font = NSFont.systemFont(ofSize: 12)
        field.isBordered = false
        field.drawsBackground = true
        field.backgroundColor = .textBackgroundColor
        field.focusRingType = .none
        field.delegate = self
        field.stringValue = seed ?? CellInput.editingText(
            for: sheet[anchor],
            numberFormat: styles.numberFormatCode(forStyle: sheet[anchor].styleIndex)
        )
        field.wantsLayer = true
        field.layer?.borderColor = NSColor.controlAccentColor.cgColor
        field.layer?.borderWidth = 2

        addSubview(field)
        editor = field
        editingAddress = anchor
        window?.makeFirstResponder(field)
        field.currentEditor()?.selectedRange = NSRange(location: field.stringValue.count, length: 0)
        delegate?.gridView(self, didBeginEditing: anchor)
    }

    var isEditing: Bool { editor != nil }

    var metricsForTesting: GridMetrics { metrics }

    /// The text currently in the editor, for mirroring into the formula bar.
    var editingText: String? { editor?.stringValue }

    func setEditingText(_ text: String) {
        guard let editor else { return }
        editor.stringValue = text
    }

    @discardableResult
    func commitEditing(moving advance: Advance) -> Bool {
        guard let editor, let address = editingAddress else { return false }
        let input = editor.stringValue
        editor.removeFromSuperview()
        self.editor = nil
        editingAddress = nil
        window?.makeFirstResponder(self)

        delegate?.gridView(self, didCommit: input, at: address, moving: advance)
        return true
    }

    func cancelEditing() {
        editor?.removeFromSuperview()
        editor = nil
        editingAddress = nil
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    private func repositionEditor() {
        guard let editor, let address = editingAddress else { return }
        editor.frame = editorFrame(for: address)
    }

    func advance(_ direction: Advance, from address: CellAddress) {
        switch direction {
        case .down: select(CellRange(CellAddress(row: address.row + 1, column: address.column)))
        case .up: select(CellRange(CellAddress(row: max(1, address.row - 1), column: address.column)))
        case .right: select(CellRange(CellAddress(row: address.row, column: address.column + 1)))
        case .left: select(CellRange(CellAddress(row: address.row, column: max(1, address.column - 1))))
        case .stay: needsDisplay = true
        }
    }
}

extension GridView: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView,
                 doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            commitEditing(moving: .down)
            return true
        case #selector(NSResponder.insertTab(_:)):
            commitEditing(moving: .right)
            return true
        case #selector(NSResponder.insertBacktab(_:)):
            commitEditing(moving: .left)
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            cancelEditing()
            return true
        default:
            return false
        }
    }
}
