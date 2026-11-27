import AppKit

enum MainMenu {
    static func build() -> NSMenu {
        let main = NSMenu()
        let name = ProcessInfo.processInfo.processName

        main.addItem(submenu("App", [
            item("About \(name)", #selector(NSApplication.orderFrontStandardAboutPanel(_:)), target: NSApp),
            .separator(),
            item("Settings…", #selector(AppDelegate.openSettings(_:)), ","),
            item("Open Config File", #selector(AppDelegate.openConfig(_:)), ""),
            .separator(),
            item("Hide \(name)", #selector(NSApplication.hide(_:)), "h", target: NSApp),
            item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option], target: NSApp),
            .separator(),
            item("Quit \(name)", #selector(NSApplication.terminate(_:)), "q", target: NSApp),
        ]))

        main.addItem(submenu("Shell", [
            item("New Window", #selector(AppDelegate.newWindow(_:)), "n"),
            item("New Tab", #selector(AppDelegate.newTab(_:)), "t"),
            .separator(),
            item("Close Tab", #selector(AppDelegate.closeTab(_:)), "w"),
            item("Close Window", #selector(AppDelegate.closeWindow(_:)), "w", [.command, .shift]),
        ]))

        main.addItem(submenu("Edit", [
            item("Undo", Selector(("undo:")), "z"),
            item("Redo", Selector(("redo:")), "z", [.command, .shift]),
            .separator(),
            item("Cut", #selector(NSText.cut(_:)), "x"),
            item("Copy", #selector(NSText.copy(_:)), "c"),
            item("Paste", #selector(NSText.paste(_:)), "v"),
            item("Select All", #selector(NSText.selectAll(_:)), "a"),
            .separator(),
            item("Clear Screen", #selector(AppDelegate.clearScreen(_:)), "k"),
        ]))

        main.addItem(submenu("View", [
            item("Zoom In", #selector(AppDelegate.increaseFontSize(_:)), "="),
            item("Zoom Out", #selector(AppDelegate.decreaseFontSize(_:)), "-"),
            item("Actual Size", #selector(AppDelegate.resetFontSize(_:)), "0"),
            .separator(),
            item("Toggle Hotkey Window", #selector(AppDelegate.toggleDropdown(_:)), ""),
        ]))

        var tabItems: [NSMenuItem] = [
            item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"),
            item("Zoom", #selector(NSWindow.performZoom(_:)), ""),
            .separator(),
            item("Show Next Tab", #selector(AppDelegate.nextTab(_:)), "]", [.command, .shift]),
            item("Show Previous Tab", #selector(AppDelegate.previousTab(_:)), "[", [.command, .shift]),
            .separator(),
        ]
        for i in 1...9 {
            let it = item(i == 9 ? "Last Tab" : "Tab \(i)", #selector(AppDelegate.selectTab(_:)), "\(i)")
            it.tag = i
            tabItems.append(it)
        }
        let window = submenu("Window", tabItems)
        main.addItem(window)
        NSApp.windowsMenu = window.submenu
        return main
    }

    private static func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let root = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu(title: title)
        items.forEach(menu.addItem)
        root.submenu = menu
        return root
    }

    private static func item(_ title: String, _ action: Selector, _ key: String = "", _ mods: NSEvent.ModifierFlags = .command, target: AnyObject? = nil) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: action, keyEquivalent: key)
        it.keyEquivalentModifierMask = mods
        // App actions go to the delegate; editing actions follow the responder chain.
        it.target = target ?? (isAppAction(action) ? NSApp.delegate : nil)
        return it
    }

    private static func isAppAction(_ s: Selector) -> Bool {
        AppDelegate.instancesRespond(to: s)
    }
}
