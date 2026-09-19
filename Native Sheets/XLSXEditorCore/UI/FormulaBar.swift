import AppKit
import XLSXKit

protocol FormulaBarDelegate: AnyObject {
    func formulaBar(_ bar: FormulaBar, didCommit text: String)
    func formulaBarDidCancel(_ bar: FormulaBar)
    func formulaBar(_ bar: FormulaBar, didJumpTo address: CellAddress)
}

/// The name box and formula field above the grid.
final class FormulaBar: NSView {
    weak var delegate: FormulaBarDelegate?

    private let nameBox = NSTextField()
    private let field = NSTextField()

    override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true

        nameBox.alignment = .center
        nameBox.font = .systemFont(ofSize: 12)
        nameBox.placeholderString = "A1"
        nameBox.target = self
        nameBox.action = #selector(nameBoxCommitted)
        nameBox.translatesAutoresizingMaskIntoConstraints = false

        field.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        field.placeholderString = "Enter a value or formula"
        field.delegate = self
        field.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: "ƒx")
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(nameBox)
        addSubview(label)
        addSubview(field)

        NSLayoutConstraint.activate([
            nameBox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            nameBox.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameBox.widthAnchor.constraint(equalToConstant: 96),

            label.leadingAnchor.constraint(equalTo: nameBox.trailingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),

            field.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
            field.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            field.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: CGSize { CGSize(width: NSView.noIntrinsicMetric, height: 32) }

    func show(address: CellAddress, cell: Cell, numberFormat: String, selection: CellRange) {
        nameBox.stringValue = selection.start == selection.end
            ? address.a1
            : "\(selection.a1)"
        guard window?.firstResponder != field.currentEditor() else { return }
        field.stringValue = CellInput.editingText(for: cell, numberFormat: numberFormat)
    }

    func mirror(_ text: String) {
        guard window?.firstResponder != field.currentEditor() else { return }
        field.stringValue = text
    }

    @objc private func nameBoxCommitted() {
        guard let address = CellAddress(a1: nameBox.stringValue.trimmingCharacters(in: .whitespaces)) else {
            return
        }
        delegate?.formulaBar(self, didJumpTo: address)
    }
}

extension FormulaBar: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            delegate?.formulaBar(self, didCommit: field.stringValue)
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            delegate?.formulaBarDidCancel(self)
            return true
        default:
            return false
        }
    }
}
