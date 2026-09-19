import AppKit
import XLSXEditorCore

// NSDocumentController must exist before the app finishes launching, so that
// reopening documents and the recent-files menu work.
_ = NSDocumentController.shared

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
