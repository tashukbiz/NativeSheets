import AppKit

/// Builds the menu bar in code, since the app is assembled without a nib.
enum MainMenu {
    static func build() -> NSMenu {
        let main = NSMenu()
        main.addItem(applicationMenu())
        main.addItem(fileMenu())
        main.addItem(editMenu())
        main.addItem(formatMenu())
        main.addItem(sheetMenu())
        main.addItem(windowMenu())
        return main
    }

    private static func submenu(_ title: String, _ build: (NSMenu) -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu(title: title)
        build(menu)
        item.submenu = menu
        return item
    }

    @discardableResult
    private static func add(_ menu: NSMenu, _ title: String, _ action: Selector?,
                            _ key: String = "", _ modifiers: NSEvent.ModifierFlags = .command,
                            represented: Any? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.representedObject = represented
        menu.addItem(item)
        return item
    }

    private static func applicationMenu() -> NSMenuItem {
        submenu("Native Sheets") { menu in
            add(menu, "About Native Sheets", #selector(NSApplication.orderFrontStandardAboutPanel(_:)))
            menu.addItem(.separator())
            add(menu, "Hide Native Sheets", #selector(NSApplication.hide(_:)), "h")
            add(menu, "Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option])
            add(menu, "Show All", #selector(NSApplication.unhideAllApplications(_:)))
            menu.addItem(.separator())
            add(menu, "Quit Native Sheets", #selector(NSApplication.terminate(_:)), "q")
        }
    }

    private static func fileMenu() -> NSMenuItem {
        submenu("File") { menu in
            add(menu, "New", #selector(NSDocumentController.newDocument(_:)), "n")
            add(menu, "Open…", #selector(NSDocumentController.openDocument(_:)), "o")
            add(menu, "Open Recent", nil).submenu = {
                let recent = NSMenu(title: "Open Recent")
                recent.perform(Selector(("_setMenuName:")), with: "NSRecentDocumentsMenu")
                return recent
            }()
            menu.addItem(.separator())
            add(menu, "Close", #selector(NSWindow.performClose(_:)), "w")
            add(menu, "Save", #selector(NSDocument.save(_:)), "s")
            add(menu, "Save As…", #selector(NSDocument.saveAs(_:)), "s", [.command, .shift])
            add(menu, "Revert to Saved", #selector(NSDocument.revertToSaved(_:)))
            menu.addItem(.separator())
            add(menu, "Page Setup…", #selector(NSDocument.runPageLayout(_:)), "p", [.command, .shift])
            add(menu, "Print…", #selector(NSDocument.printDocument(_:)), "p")
        }
    }

    private static func editMenu() -> NSMenuItem {
        submenu("Edit") { menu in
            add(menu, "Undo", Selector(("undo:")), "z")
            add(menu, "Redo", Selector(("redo:")), "z", [.command, .shift])
            menu.addItem(.separator())
            add(menu, "Cut", #selector(AppDelegate.cutCells(_:)), "x")
            add(menu, "Copy", #selector(AppDelegate.copyCells(_:)), "c")
            add(menu, "Paste", #selector(AppDelegate.pasteCells(_:)), "v")
            menu.addItem(.separator())
            add(menu, "Edit Cell", #selector(AppDelegate.editCell(_:)), "\u{0003}", [])
            menu.addItem(.separator())
            add(menu, "Insert Rows", #selector(AppDelegate.insertRows(_:)), "i", [.command, .shift])
            add(menu, "Delete Rows", #selector(AppDelegate.deleteRows(_:)), "\u{8}", [.command, .shift])
            add(menu, "Insert Columns", #selector(AppDelegate.insertColumns(_:)), "i",
                [.command, .option, .shift])
            add(menu, "Delete Columns", #selector(AppDelegate.deleteColumns(_:)), "\u{8}",
                [.command, .option, .shift])
            menu.addItem(.separator())
            add(menu, "Recalculate", #selector(AppDelegate.recalculate(_:)), "=", [.command, .shift])
        }
    }

    private static func formatMenu() -> NSMenuItem {
        submenu("Format") { menu in
            add(menu, "Bold", #selector(AppDelegate.toggleBold(_:)), "b")
            add(menu, "Italic", #selector(AppDelegate.toggleItalic(_:)), "i")
            add(menu, "Underline", #selector(AppDelegate.toggleUnderline(_:)), "u")
            menu.addItem(.separator())
            add(menu, "Align Left", #selector(AppDelegate.alignLeft(_:)), "{")
            add(menu, "Align Center", #selector(AppDelegate.alignCenter(_:)), "|")
            add(menu, "Align Right", #selector(AppDelegate.alignRight(_:)), "}")
            add(menu, "Wrap Text", #selector(AppDelegate.toggleWrapText(_:)))
            menu.addItem(.separator())

            menu.addItem(submenu("Number") { numbers in
                for format in [
                    ("General", "General"),
                    ("Number", "#,##0.00"),
                    ("Integer", "#,##0"),
                    ("Percent", "0.0%"),
                    ("Currency", "\"$\"#,##0.00"),
                    ("Date", "yyyy-mm-dd"),
                    ("Date and time", "yyyy-mm-dd hh:mm"),
                    ("Text", "@"),
                ] {
                    add(numbers, format.0, #selector(AppDelegate.applyNumberFormat(_:)),
                        represented: format.1)
                }
            })
            menu.addItem(.separator())
            add(menu, "Merge Cells", #selector(AppDelegate.mergeCells(_:)), "m", [.command, .control])
            add(menu, "Unmerge Cells", #selector(AppDelegate.unmergeCells(_:)), "m",
                [.command, .control, .shift])
            add(menu, "Freeze Panes at Selection", #selector(AppDelegate.toggleFreeze(_:)))
        }
    }

    private static func sheetMenu() -> NSMenuItem {
        submenu("Sheet") { menu in
            add(menu, "New Sheet", #selector(AppDelegate.addSheet(_:)), "t", [.command, .shift])
            add(menu, "Rename Sheet…", #selector(AppDelegate.renameSheet(_:)))
        }
    }

    private static func windowMenu() -> NSMenuItem {
        let item = submenu("Window") { menu in
            add(menu, "Minimize", #selector(NSWindow.performMiniaturize(_:)), "m")
            add(menu, "Zoom", #selector(NSWindow.performZoom(_:)))
            menu.addItem(.separator())
            add(menu, "Bring All to Front", #selector(NSApplication.arrangeInFront(_:)))
        }
        NSApp.windowsMenu = item.submenu
        return item
    }
}
