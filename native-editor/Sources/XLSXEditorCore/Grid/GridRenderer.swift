import AppKit
import XLSXKit

/// Draws the visible part of a sheet.
struct GridRenderer {
    let sheet: Worksheet
    let styles: WorkbookStyles
    let metrics: GridMetrics
    let selection: CellRange
    let activeCell: CellAddress
    /// Where the scrolled content starts, used to pin the headers and any
    /// frozen rows and columns.
    let origin: CGPoint

    private static let gridLine = NSColor.separatorColor.withAlphaComponent(0.55)
    private static let headerBackground = NSColor.controlBackgroundColor
    private static let headerSelected = NSColor.controlAccentColor.withAlphaComponent(0.20)
    private static let selectionFill = NSColor.controlAccentColor.withAlphaComponent(0.12)
    private static let cellPadding: CGFloat = 4

    func draw(in dirtyRect: CGRect) {
        let body = CGRect(
            x: max(dirtyRect.minX, origin.x + GridMetrics.headerWidth),
            y: max(dirtyRect.minY, origin.y + GridMetrics.headerHeight),
            width: dirtyRect.maxX, height: dirtyRect.maxY
        )
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        NSColor.textBackgroundColor.setFill()
        dirtyRect.fill()

        // The sheet is drawn as up to four panes. A frozen band is pinned on
        // one axis only: frozen columns still scroll vertically, frozen rows
        // still scroll horizontally.
        let frozen = frozenExtent()
        let visible = metrics.visibleRange(in: body)
        let scrolledColumns = max(frozen.columns + 1, visible.columns.lowerBound)...max(
            frozen.columns + 1, visible.columns.upperBound)
        let scrolledRows = max(frozen.rows + 1, visible.rows.lowerBound)...max(
            frozen.rows + 1, visible.rows.upperBound)
        let panes = panes(frozen: frozen, dirtyRect: dirtyRect,
                          scrolledColumns: scrolledColumns, scrolledRows: scrolledRows)

        for pane in panes { drawPane(pane, context: context) }

        drawFrozenDividers(frozen, in: dirtyRect, context: context)
        drawSelection(in: panes, context: context)
        drawHeaders(in: dirtyRect, frozen: frozen, scrolled: (scrolledColumns, scrolledRows),
                    context: context)
    }

    /// One region of the sheet, with the shift its contents need and the
    /// rectangle they are confined to.
    struct Pane {
        let columns: ClosedRange<Int>
        let rows: ClosedRange<Int>
        let offset: CGPoint
        let clip: CGRect
    }

    private func panes(frozen: (rows: Int, columns: Int, x: CGFloat, y: CGFloat), dirtyRect: CGRect,
                       scrolledColumns: ClosedRange<Int>, scrolledRows: ClosedRange<Int>) -> [Pane] {
        let left = origin.x + GridMetrics.headerWidth
        let top = origin.y + GridMetrics.headerHeight

        var panes = [Pane(columns: scrolledColumns, rows: scrolledRows, offset: .zero,
                          clip: CGRect(x: frozen.x, y: frozen.y,
                                       width: dirtyRect.maxX - frozen.x,
                                       height: dirtyRect.maxY - frozen.y))]
        if frozen.columns > 0 {
            panes.append(Pane(columns: 1...frozen.columns, rows: scrolledRows,
                              offset: CGPoint(x: origin.x, y: 0),
                              clip: CGRect(x: left, y: frozen.y, width: frozen.x - left,
                                           height: dirtyRect.maxY - frozen.y)))
        }
        if frozen.rows > 0 {
            panes.append(Pane(columns: scrolledColumns, rows: 1...frozen.rows,
                              offset: CGPoint(x: 0, y: origin.y),
                              clip: CGRect(x: frozen.x, y: top,
                                           width: dirtyRect.maxX - frozen.x, height: frozen.y - top)))
        }
        if frozen.rows > 0, frozen.columns > 0 {
            panes.append(Pane(columns: 1...frozen.columns, rows: 1...frozen.rows, offset: origin,
                              clip: CGRect(x: left, y: top,
                                           width: frozen.x - left, height: frozen.y - top)))
        }
        return panes
    }

    private func drawPane(_ pane: Pane, context: CGContext) {
        guard pane.clip.width > 0, pane.clip.height > 0 else { return }
        context.saveGState()
        context.clip(to: pane.clip)
        NSColor.textBackgroundColor.setFill()
        context.fill(pane.clip)
        drawCells(in: CellRange(start: CellAddress(row: pane.rows.lowerBound, column: pane.columns.lowerBound),
                                end: CellAddress(row: pane.rows.upperBound, column: pane.columns.upperBound)),
                  context: context, offset: pane.offset)
        context.restoreGState()
    }

    /// Where the scrollable area begins, once frozen bands have taken their space.
    private func frozenExtent() -> (rows: Int, columns: Int, x: CGFloat, y: CGFloat) {
        let freeze = sheet.freeze ?? FreezePane(columns: 0, rows: 0)
        let columns = max(0, min(freeze.columns, metrics.columnCount))
        let rows = max(0, min(freeze.rows, metrics.rowCount))
        return (
            rows, columns,
            origin.x + (columns > 0 ? metrics.x(ofColumn: columns + 1) : GridMetrics.headerWidth),
            origin.y + (rows > 0 ? metrics.y(ofRow: rows + 1) : GridMetrics.headerHeight)
        )
    }

    private func drawFrozenDividers(_ frozen: (rows: Int, columns: Int, x: CGFloat, y: CGFloat),
                                    in dirtyRect: CGRect, context: CGContext) {
        NSColor.separatorColor.setFill()
        if frozen.columns > 0 {
            context.fill(CGRect(x: frozen.x - 1, y: origin.y, width: 1, height: dirtyRect.maxY))
        }
        if frozen.rows > 0 {
            context.fill(CGRect(x: origin.x, y: frozen.y - 1, width: dirtyRect.maxX, height: 1))
        }
    }

    // MARK: - Cells

    private func drawCells(in range: CellRange, context: CGContext, offset: CGPoint = .zero) {
        let columns = range.columns.clamped(to: 1...max(1, metrics.columnCount))
        let rows = range.rows.clamped(to: 1...max(1, metrics.rowCount))

        if sheet.showGridLines {
            GridRenderer.gridLine.setFill()
            for column in columns.lowerBound...(columns.upperBound + 1) where column <= metrics.columnCount + 1 {
                context.fill(CGRect(x: offset.x + metrics.x(ofColumn: column) - 0.5,
                                    y: offset.y + metrics.y(ofRow: rows.lowerBound),
                                    width: 1,
                                    height: metrics.y(ofRow: rows.upperBound + 1) - metrics.y(ofRow: rows.lowerBound)))
            }
            for row in rows.lowerBound...(rows.upperBound + 1) where row <= metrics.rowCount + 1 {
                context.fill(CGRect(x: offset.x + metrics.x(ofColumn: columns.lowerBound),
                                    y: offset.y + metrics.y(ofRow: row) - 0.5,
                                    width: metrics.x(ofColumn: columns.upperBound + 1) - metrics.x(ofColumn: columns.lowerBound),
                                    height: 1))
            }
        }

        // Two passes: every background first, then every label. Otherwise a
        // filled cell would paint over the text spilling into it from its
        // neighbour.
        var painted: [(cell: Cell, address: CellAddress, rect: CGRect)] = []
        var drawnMerges = Set<CellRange>()

        for row in rows {
            for column in columns {
                let address = CellAddress(row: row, column: column)
                var rect = metrics.rect(of: address)
                var source = address

                if let merge = sheet.mergeContaining(address) {
                    guard drawnMerges.insert(merge).inserted else { continue }
                    rect = metrics.rect(of: merge)
                    source = merge.start
                }
                let cell = sheet[source]
                guard !cell.isDefault else { continue }
                rect = rect.offsetBy(dx: offset.x, dy: offset.y)
                drawBackground(cell, in: rect, context: context)
                painted.append((cell, address, rect))
            }
        }

        for entry in painted {
            drawLabel(entry.cell, at: entry.address, in: entry.rect, context: context,
                      merged: sheet.mergeContaining(entry.address) != nil)
        }
    }

    private func drawBackground(_ cell: Cell, in rect: CGRect, context: CGContext) {
        let format = styles.format(at: cell.styleIndex)
        if let rgb = styles.fill(at: format.fillID).solidRGB, let color = NSColor(argbHex: rgb) {
            color.setFill()
            context.fill(rect)
        }
        drawBorders(styles.border(at: format.borderID), in: rect, context: context)
    }

    private func drawLabel(_ cell: Cell, at address: CellAddress, in rect: CGRect,
                           context: CGContext, merged: Bool) {
        let format = styles.format(at: cell.styleIndex)
        let rendered = NumberFormat.shared(for: styles.numberFormatCode(id: format.numberFormatID))
            .string(for: cell.value)
        guard !rendered.text.isEmpty else { return }

        let font = styles.font(at: format.fontID)
        let isText = cell.value.textValue != nil
        let attributes = textAttributes(font: font, format: format, colorOverride: rendered.colorRGB,
                                        isText: isText)
        let text = NSAttributedString(string: rendered.text, attributes: attributes)
        let inset = rect.insetBy(dx: GridRenderer.cellPadding, dy: 1)
        guard inset.width > 1 else { return }

        if format.alignment.wrapText {
            let bounds = text.boundingRect(with: CGSize(width: inset.width, height: .greatestFiniteMagnitude),
                                           options: [.usesLineFragmentOrigin])
            var wrapped = inset
            wrapped.origin.y = verticalOrigin(of: bounds.size, in: inset, format: format)
            wrapped.size.height = bounds.height
            context.saveGState()
            context.clip(to: rect)
            text.draw(with: wrapped, options: [.usesLineFragmentOrigin], context: nil)
            context.restoreGState()
            return
        }

        let size = text.size()
        // Numbers that do not fit show as ### rather than a misleading truncation.
        if size.width > inset.width, !isText, cell.value.numberValue != nil {
            let hashes = NSAttributedString(string: "###", attributes: attributes)
            hashes.draw(at: CGPoint(x: inset.maxX - min(hashes.size().width, inset.width),
                                    y: verticalOrigin(of: hashes.size(), in: inset, format: format)))
            return
        }

        // Long text spills into empty neighbours, as it does in every
        // spreadsheet; a neighbour with content clips it.
        var drawRect = inset
        if isText, size.width > inset.width, !merged {
            drawRect = spilling(inset, from: address, needing: size.width,
                                alignment: attributes[.paragraphStyle] as? NSParagraphStyle)
        }
        drawRect.origin.y = verticalOrigin(of: size, in: inset, format: format)
        drawRect.size.height = size.height

        context.saveGState()
        context.clip(to: CGRect(x: drawRect.minX - GridRenderer.cellPadding, y: rect.minY,
                                width: drawRect.width + GridRenderer.cellPadding * 2, height: rect.height))
        text.draw(in: drawRect)
        context.restoreGState()
    }

    private func spilling(_ inset: CGRect, from address: CellAddress, needing width: CGFloat,
                          alignment: NSParagraphStyle?) -> CGRect {
        var rect = inset
        let toTheRight = (alignment?.alignment ?? .left) != .right

        if toTheRight {
            var column = address.column + 1
            while rect.width < width, column <= metrics.columnCount,
                  sheet[CellAddress(row: address.row, column: column)].isBlank {
                rect.size.width += metrics.width(ofColumn: column)
                column += 1
            }
        } else {
            var column = address.column - 1
            while rect.width < width, column >= 1,
                  sheet[CellAddress(row: address.row, column: column)].isBlank {
                let extra = metrics.width(ofColumn: column)
                rect.origin.x -= extra
                rect.size.width += extra
                column -= 1
            }
        }
        return rect
    }

    private func verticalOrigin(of size: CGSize, in rect: CGRect, format: WorkbookStyles.CellFormat) -> CGFloat {
        switch format.alignment.vertical {
        case .top: return rect.minY
        case .center: return rect.midY - size.height / 2
        default: return rect.maxY - size.height
        }
    }

    private func textAttributes(font: WorkbookStyles.Font, format: WorkbookStyles.CellFormat,
                                colorOverride: String?, isText: Bool) -> [NSAttributedString.Key: Any] {
        var traits: NSFontDescriptor.SymbolicTraits = []
        if font.bold { traits.insert(.bold) }
        if font.italic { traits.insert(.italic) }

        let base = NSFont(name: font.name, size: font.size) ?? NSFont.systemFont(ofSize: font.size)
        let descriptor = base.fontDescriptor.withSymbolicTraits(traits)
        let resolved = NSFont(descriptor: descriptor, size: font.size) ?? base

        let paragraph = NSMutableParagraphStyle()
        // Text sits left and numbers right unless the style says otherwise.
        switch format.alignment.horizontal {
        case .left, .justify: paragraph.alignment = .left
        case .center, .centerContinuous: paragraph.alignment = .center
        case .right: paragraph.alignment = .right
        default: paragraph.alignment = isText ? .left : .right
        }
        paragraph.lineBreakMode = format.alignment.wrapText ? .byWordWrapping : .byClipping

        var attributes: [NSAttributedString.Key: Any] = [
            .font: resolved,
            .paragraphStyle: paragraph,
            .foregroundColor: (colorOverride ?? font.colorRGB).flatMap { NSColor(argbHex: $0) }
                ?? NSColor.textColor,
        ]
        if font.underline { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if font.strikethrough { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        return attributes
    }

    private func drawBorders(_ border: WorkbookStyles.Border, in rect: CGRect, context: CGContext) {
        func stroke(_ edge: WorkbookStyles.Edge?, _ line: CGRect) {
            guard let edge else { return }
            (edge.colorRGB.flatMap { NSColor(argbHex: $0) } ?? NSColor.separatorColor).setFill()
            context.fill(line)
        }
        let weight: CGFloat = 1
        stroke(border.top, CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: weight))
        stroke(border.bottom, CGRect(x: rect.minX, y: rect.maxY - weight, width: rect.width, height: weight))
        stroke(border.left, CGRect(x: rect.minX, y: rect.minY, width: weight, height: rect.height))
        stroke(border.right, CGRect(x: rect.maxX - weight, y: rect.minY, width: weight, height: rect.height))
    }

    // MARK: - Selection

    /// Drawn once per pane, clipped to it, so a selection in the scrolled body
    /// cannot paint over the frozen rows or columns above and beside it.
    private func drawSelection(in panes: [Pane], context: CGContext) {
        let selectionRect = metrics.rect(of: selection)
        let merge = sheet.mergeContaining(activeCell)
        let activeSource = merge?.start ?? activeCell
        let activeRect = metrics.rect(of: merge ?? CellRange(activeCell))

        for pane in panes {
            guard pane.clip.width > 0, pane.clip.height > 0 else { continue }
            context.saveGState()
            context.clip(to: pane.clip)

            let rect = selectionRect.offsetBy(dx: pane.offset.x, dy: pane.offset.y)
            if selection.start != selection.end {
                GridRenderer.selectionFill.setFill()
                context.fill(rect)
            }

            // The active cell stays unshaded, so it is redrawn over the fill.
            let active = activeRect.offsetBy(dx: pane.offset.x, dy: pane.offset.y)
            NSColor.textBackgroundColor.setFill()
            context.fill(active)
            let cell = sheet[activeSource]
            if !cell.isDefault {
                drawBackground(cell, in: active, context: context)
                drawLabel(cell, at: activeSource, in: active, context: context, merged: merge != nil)
            }
            drawValidationButton(for: activeSource, in: active, context: context)

            // Last, so neither the cell's own fill nor the button covers it.
            NSColor.controlAccentColor.setStroke()
            context.setLineWidth(2)
            context.stroke(rect.insetBy(dx: 1, dy: 1))

            context.restoreGState()
        }
    }

    /// The disclosure button a cell restricted to a list of values carries,
    /// shown on the active cell as a spreadsheet does.
    private func drawValidationButton(for address: CellAddress, in rect: CGRect, context: CGContext) {
        guard sheet.listValidation(at: address) != nil else { return }
        let button = GridRenderer.validationButtonRect(rect)
        guard button.width > 4, button.height > 4 else { return }

        NSColor.controlBackgroundColor.setFill()
        context.fill(button)
        NSColor.separatorColor.setStroke()
        context.setLineWidth(1)
        context.stroke(button.insetBy(dx: 0.5, dy: 0.5))

        let arrow = NSBezierPath()
        let middle = CGPoint(x: button.midX, y: button.midY + 1.5)
        arrow.move(to: CGPoint(x: middle.x - 3.5, y: middle.y - 2))
        arrow.line(to: CGPoint(x: middle.x + 3.5, y: middle.y - 2))
        arrow.line(to: CGPoint(x: middle.x, y: middle.y + 2.5))
        arrow.close()
        NSColor.secondaryLabelColor.setFill()
        arrow.fill()
    }

    static func validationButtonRect(_ cellRect: CGRect) -> CGRect {
        let side = min(16, cellRect.height - 2)
        return CGRect(x: cellRect.maxX - side - 1, y: cellRect.midY - side / 2, width: side, height: side)
    }

    // MARK: - Headers

    private func drawHeaders(in dirtyRect: CGRect,
                             frozen: (rows: Int, columns: Int, x: CGFloat, y: CGFloat),
                             scrolled: (columns: ClosedRange<Int>, rows: ClosedRange<Int>),
                             context: CGContext) {
        GridRenderer.headerBackground.setFill()
        context.fill(CGRect(x: origin.x, y: origin.y, width: dirtyRect.maxX, height: GridMetrics.headerHeight))
        context.fill(CGRect(x: origin.x, y: origin.y, width: GridMetrics.headerWidth, height: dirtyRect.maxY))

        columnHeaders(scrolled.columns, offsetX: 0, context: context,
                      clip: CGRect(x: frozen.x, y: origin.y,
                                   width: dirtyRect.maxX - frozen.x, height: GridMetrics.headerHeight))
        if frozen.columns > 0 {
            columnHeaders(1...frozen.columns, offsetX: origin.x, context: context,
                          clip: CGRect(x: origin.x + GridMetrics.headerWidth, y: origin.y,
                                       width: frozen.x - origin.x - GridMetrics.headerWidth,
                                       height: GridMetrics.headerHeight))
        }

        rowHeaders(scrolled.rows, offsetY: 0, context: context,
                   clip: CGRect(x: origin.x, y: frozen.y,
                                width: GridMetrics.headerWidth, height: dirtyRect.maxY - frozen.y))
        if frozen.rows > 0 {
            rowHeaders(1...frozen.rows, offsetY: origin.y, context: context,
                       clip: CGRect(x: origin.x, y: origin.y + GridMetrics.headerHeight,
                                    width: GridMetrics.headerWidth,
                                    height: frozen.y - origin.y - GridMetrics.headerHeight))
        }

        // The corner covers the point where the two header bands meet.
        GridRenderer.headerBackground.setFill()
        context.fill(CGRect(x: origin.x, y: origin.y,
                            width: GridMetrics.headerWidth, height: GridMetrics.headerHeight))
        NSColor.separatorColor.setFill()
        context.fill(CGRect(x: origin.x, y: origin.y + GridMetrics.headerHeight - 1,
                            width: dirtyRect.maxX, height: 1))
        context.fill(CGRect(x: origin.x + GridMetrics.headerWidth - 1, y: origin.y,
                            width: 1, height: dirtyRect.maxY))
    }

    private func columnHeaders(_ columns: ClosedRange<Int>, offsetX: CGFloat, context: CGContext,
                               clip: CGRect) {
        guard clip.width > 0 else { return }
        context.saveGState()
        context.clip(to: clip)
        GridRenderer.headerBackground.setFill()
        context.fill(clip)
        for column in columns where column <= metrics.columnCount {
            drawHeaderCell(
                CGRect(x: metrics.x(ofColumn: column) + offsetX, y: origin.y,
                       width: metrics.width(ofColumn: column), height: GridMetrics.headerHeight),
                title: CellAddress.columnName(column),
                selected: selection.columns.contains(column),
                context: context
            )
        }
        context.restoreGState()
    }

    private func rowHeaders(_ rows: ClosedRange<Int>, offsetY: CGFloat, context: CGContext,
                            clip: CGRect) {
        guard clip.height > 0 else { return }
        context.saveGState()
        context.clip(to: clip)
        GridRenderer.headerBackground.setFill()
        context.fill(clip)
        for row in rows where row <= metrics.rowCount {
            drawHeaderCell(
                CGRect(x: origin.x, y: metrics.y(ofRow: row) + offsetY,
                       width: GridMetrics.headerWidth, height: metrics.height(ofRow: row)),
                title: String(row),
                selected: selection.rows.contains(row),
                context: context
            )
        }
        context.restoreGState()
    }

    private func drawHeaderCell(_ rect: CGRect, title: String, selected: Bool, context: CGContext) {
        if selected {
            GridRenderer.headerSelected.setFill()
            context.fill(rect)
        }
        NSColor.separatorColor.setFill()
        context.fill(CGRect(x: rect.maxX - 1, y: rect.minY, width: 1, height: rect.height))
        context.fill(CGRect(x: rect.minX, y: rect.maxY - 1, width: rect.width, height: 1))

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let text = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: selected ? .semibold : .regular),
            .foregroundColor: selected ? NSColor.controlAccentColor : NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph,
        ])
        let size = text.size()
        guard rect.height >= size.height else { return }
        text.draw(in: CGRect(x: rect.minX, y: rect.midY - size.height / 2,
                             width: rect.width, height: size.height))
    }
}

extension NSColor {
    /// Parses the `AARRGGBB` (or `RRGGBB`) hex the file format uses.
    convenience init?(argbHex hex: String) {
        var digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        if digits.count == 6 { digits = "FF" + digits }
        guard digits.count == 8, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: CGFloat((value >> 24) & 0xFF) / 255
        )
    }
}

extension CellValue {
    var textValue: String? {
        if case .text(let value) = self { return value }
        return nil
    }
}

extension NSColor {
    /// Relative luminance, for deciding whether dark or light text reads
    /// better on top of a colour taken from the file.
    var isLight: Bool {
        guard let srgb = usingColorSpace(.sRGB) else { return true }
        let luminance = 0.299 * srgb.redComponent
            + 0.587 * srgb.greenComponent
            + 0.114 * srgb.blueComponent
        return luminance > 0.6
    }
}
