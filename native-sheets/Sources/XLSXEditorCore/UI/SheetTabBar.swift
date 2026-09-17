import AppKit
import XLSXKit

protocol SheetTabBarDelegate: AnyObject {
    func sheetTabBar(_ bar: SheetTabBar, didSelect index: Int)
    func sheetTabBar(_ bar: SheetTabBar, didRename index: Int, to name: String)
    func sheetTabBar(_ bar: SheetTabBar, didMove index: Int, to destination: Int)
    func sheetTabBarDidAddSheet(_ bar: SheetTabBar)
    func sheetTabBar(_ bar: SheetTabBar, didRequestDelete index: Int)
    func sheetTabBar(_ bar: SheetTabBar, didRequestDuplicate index: Int)
}

/// The row of sheet tabs along the bottom of the window: the multi-page part of
/// a multi-page document.
final class SheetTabBar: NSView {
    weak var delegate: SheetTabBarDelegate?

    private struct Tab {
        let name: String
        let color: NSColor?
        var rect: CGRect = .zero
    }

    private var tabs: [Tab] = []
    private var selectedIndex = 0
    private var addButtonRect: CGRect = .zero
    private var editor: NSTextField?
    private var editingIndex: Int?
    private var dragOrigin: (index: Int, start: CGPoint)?
    private var dropIndex: Int?

    private static let height: CGFloat = 30
    private static let padding: CGFloat = 14
    private static let addButtonWidth: CGFloat = 30

    override var isFlipped: Bool { true }
    override var intrinsicContentSize: CGSize {
        CGSize(width: NSView.noIntrinsicMetric, height: SheetTabBar.height)
    }

    func show(sheets: [Worksheet], selected: Int) {
        tabs = sheets.map { Tab(name: $0.name, color: $0.tabColor.flatMap { NSColor(argbHex: $0) }) }
        selectedIndex = selected
        layoutTabs()
        needsDisplay = true
    }

    private func layoutTabs() {
        var x: CGFloat = 8
        for index in tabs.indices {
            let width = SheetTabBar.width(of: tabs[index].name)
            tabs[index].rect = CGRect(x: x, y: 3, width: width, height: SheetTabBar.height - 6)
            x += width + 2
        }
        addButtonRect = CGRect(x: x + 4, y: 5, width: SheetTabBar.addButtonWidth, height: SheetTabBar.height - 10)
    }

    /// Readable against whatever the sheet's colour turns out to be: the
    /// sample's tabs run from near-black navy to pale grey.
    static func labelColor(on fill: NSColor?, selected: Bool) -> NSColor {
        guard !selected, let fill else {
            return selected ? .labelColor : .secondaryLabelColor
        }
        return fill.isLight ? NSColor.black.withAlphaComponent(0.8) : .white
    }

    private static func width(of name: String) -> CGFloat {
        let size = NSAttributedString(string: name, attributes: [.font: NSFont.systemFont(ofSize: 12)]).size()
        return max(56, size.width + padding * 2)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: CGRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        NSColor.windowBackgroundColor.setFill()
        context.fill(bounds)
        NSColor.separatorColor.setFill()
        context.fill(CGRect(x: 0, y: 0, width: bounds.width, height: 1))

        for (index, tab) in tabs.enumerated() {
            let selected = index == selectedIndex
            let path = NSBezierPath(roundedRect: tab.rect, xRadius: 5, yRadius: 5)

            // An underline reads as "this tab is selected", so a sheet's own
            // colour fills its tab instead and only underlines the selected
            // one, which is what a spreadsheet does.
            if selected {
                NSColor.controlBackgroundColor.setFill()
                path.fill()
                NSColor.controlAccentColor.setStroke()
                path.lineWidth = 1.5
                path.stroke()
                if let color = tab.color {
                    color.setFill()
                    NSBezierPath(roundedRect: CGRect(x: tab.rect.minX + 6, y: tab.rect.maxY - 5,
                                                     width: tab.rect.width - 12, height: 3),
                                 xRadius: 1.5, yRadius: 1.5).fill()
                }
            } else if let color = tab.color {
                color.setFill()
                path.fill()
            }

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            paragraph.lineBreakMode = .byTruncatingTail
            let text = NSAttributedString(string: tab.name, attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: selected ? .semibold : .regular),
                .foregroundColor: SheetTabBar.labelColor(on: tab.color, selected: selected),
                .paragraphStyle: paragraph,
            ])
            text.draw(in: CGRect(x: tab.rect.minX, y: tab.rect.midY - text.size().height / 2,
                                 width: tab.rect.width, height: text.size().height))
        }

        if let dropIndex, dropIndex < tabs.count || dropIndex == tabs.count {
            let x = dropIndex < tabs.count ? tabs[dropIndex].rect.minX : (tabs.last?.rect.maxX ?? 8)
            NSColor.controlAccentColor.setFill()
            context.fill(CGRect(x: x - 1, y: 3, width: 2, height: SheetTabBar.height - 6))
        }

        let plus = NSAttributedString(string: "+", attributes: [
            .font: NSFont.systemFont(ofSize: 16, weight: .light),
            .foregroundColor: NSColor.secondaryLabelColor,
        ])
        plus.draw(at: CGPoint(x: addButtonRect.midX - plus.size().width / 2,
                              y: addButtonRect.midY - plus.size().height / 2))
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        endRenaming()

        if addButtonRect.contains(point) {
            delegate?.sheetTabBarDidAddSheet(self)
            return
        }
        guard let index = tabs.firstIndex(where: { $0.rect.contains(point) }) else { return }

        if event.clickCount >= 2 {
            beginRenaming(index)
            return
        }
        dragOrigin = (index, point)
        delegate?.sheetTabBar(self, didSelect: index)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragOrigin else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard abs(point.x - dragOrigin.start.x) > 6 else { return }

        dropIndex = tabs.firstIndex { point.x < $0.rect.midX } ?? tabs.count
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if let dragOrigin, let dropIndex {
            // Removing the tab first shifts everything after it left by one.
            let destination = dropIndex > dragOrigin.index ? dropIndex - 1 : dropIndex
            if destination != dragOrigin.index {
                delegate?.sheetTabBar(self, didMove: dragOrigin.index, to: destination)
            }
        }
        dragOrigin = nil
        dropIndex = nil
        needsDisplay = true
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        guard let index = tabs.firstIndex(where: { $0.rect.contains(point) }) else { return nil }
        delegate?.sheetTabBar(self, didSelect: index)

        let menu = NSMenu()
        menu.addItem(withTitle: "Rename…", action: #selector(renameFromMenu), keyEquivalent: "")
            .target = self
        menu.addItem(withTitle: "Duplicate", action: #selector(duplicateFromMenu), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        let delete = menu.addItem(withTitle: "Delete", action: #selector(deleteFromMenu), keyEquivalent: "")
        delete.target = self
        delete.isEnabled = tabs.count > 1
        return menu
    }

    @objc private func renameFromMenu() { beginRenaming(selectedIndex) }
    @objc private func duplicateFromMenu() { delegate?.sheetTabBar(self, didRequestDuplicate: selectedIndex) }
    @objc private func deleteFromMenu() { delegate?.sheetTabBar(self, didRequestDelete: selectedIndex) }

    // MARK: - Renaming

    func beginRenaming(_ index: Int) {
        guard tabs.indices.contains(index) else { return }
        endRenaming()

        let field = NSTextField(frame: tabs[index].rect.insetBy(dx: 2, dy: 3))
        field.stringValue = tabs[index].name
        field.font = .systemFont(ofSize: 12)
        field.alignment = .center
        field.delegate = self
        addSubview(field)
        editor = field
        editingIndex = index
        window?.makeFirstResponder(field)
    }

    private func endRenaming() {
        editor?.removeFromSuperview()
        editor = nil
        editingIndex = nil
    }
}

extension SheetTabBar: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard let index = editingIndex, let editor else { return false }
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            let name = editor.stringValue
            endRenaming()
            delegate?.sheetTabBar(self, didRename: index, to: name)
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            endRenaming()
            return true
        default:
            return false
        }
    }
}
