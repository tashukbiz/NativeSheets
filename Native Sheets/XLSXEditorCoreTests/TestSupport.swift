import AppKit
import XLSXKit
@testable import XLSXEditorCore

/// Synthesized events, so the tests exercise the same handlers a real click or
/// keystroke would.
extension NSEvent {
    enum ArrowDirection {
        case up, down, left, right

        var functionKey: Int {
            switch self {
            case .up: return NSUpArrowFunctionKey
            case .down: return NSDownArrowFunctionKey
            case .left: return NSLeftArrowFunctionKey
            case .right: return NSRightArrowFunctionKey
            }
        }
    }

    static func arrow(_ direction: ArrowDirection, shift: Bool = false, command: Bool = false) -> NSEvent {
        var flags: NSEvent.ModifierFlags = [.function, .numericPad]
        if shift { flags.insert(.shift) }
        if command { flags.insert(.command) }
        return key(String(UnicodeScalar(UInt32(direction.functionKey))!), flags: flags)
    }

    static func character(_ text: String) -> NSEvent { key(text) }
    static var returnKey: NSEvent { key("\r") }
    static var deleteKey: NSEvent { key("\u{7F}") }

    static func key(_ characters: String, flags: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
            windowNumber: 0, context: nil, characters: characters,
            charactersIgnoringModifiers: characters, isARepeat: false, keyCode: 0
        )!
    }

    /// `point` is in `view`'s own coordinates, which for the grid are flipped;
    /// the event carries the window coordinates the view converts back.
    static func click(at point: CGPoint, in view: NSView, clickCount: Int = 1,
                      flags: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.mouseEvent(
            with: .leftMouseDown, location: view.convert(point, to: nil), modifierFlags: flags,
            timestamp: 0, windowNumber: view.window?.windowNumber ?? 0, context: nil,
            eventNumber: 0, clickCount: clickCount, pressure: 1
        )!
    }
}

extension GridView {
    /// The middle of a cell, in the view's coordinates.
    func centerOfCell(_ address: CellAddress) -> CGPoint {
        let rect = metricsForTesting.rect(of: address)
        return CGPoint(x: rect.midX, y: rect.midY)
    }

    /// Renders the grid into an image, which is how the drawing code is checked
    /// without a screen.
    func renderForTesting(size: CGSize) -> NSImage? {
        let clip = NSClipView(frame: CGRect(origin: .zero, size: size))
        let scroll = NSScrollView(frame: CGRect(origin: .zero, size: size))
        scroll.contentView = clip
        scroll.documentView = self

        guard let bitmap = bitmapImageRepForCachingDisplay(in: CGRect(origin: .zero, size: size)) else {
            return nil
        }
        cacheDisplay(in: CGRect(origin: .zero, size: size), to: bitmap)
        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        return image
    }
}
