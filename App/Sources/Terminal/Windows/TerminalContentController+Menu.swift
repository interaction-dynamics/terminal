import AppKit

extension TerminalContentController {
    // MARK: Menu button

    @objc func showMenu() {
        let menu = NSMenu()
        func add(_ title: String, _ action: Selector, _ target: AnyObject?, key: String = "") {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = target
            menu.addItem(item)
        }
        let app = NSApp.delegate as AnyObject?
        add("Settings…", #selector(openSettingsTab), self, key: ",")
        add("Check for Updates…", #selector(AppDelegate.checkForUpdates(_:)), app)
        add("Show Onboarding…", #selector(AppDelegate.showOnboarding(_:)), app)
        add("Send Feedback…", #selector(AppDelegate.sendFeedback(_:)), app)
        menu.addItem(.separator())
        add("About \(AppInfo.displayName)", #selector(showAbout), self)
        add("Quit \(AppInfo.displayName)", #selector(NSApplication.terminate(_:)), NSApp, key: "q")
        menu.appearance = NSAppearance(named: Theme.current.background.brightness < 0.5 ? .darkAqua : .aqua)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: menuButton.bounds.maxY + 4), in: menuButton)
    }

    @objc func showAbout() {
        AboutWindow.shared.show(over: root.window)
    }

    // MARK: Settings tab

    /// Opens the Settings tab, or switches to it.
    @objc func openSettingsTab() {
        if settingsView == nil {
            let v = SettingsView()
            v.isHidden = true
            root.addSubview(v, positioned: .below, relativeTo: menuButton)
            root.settings = v
            settingsView = v
        }
        settingsOpen = true
        showSettings(true)
    }

    func closeSettingsTab() {
        guard settingsOpen else { return }
        settingsOpen = false
        showSettings(false)
    }

    func showSettings(_ show: Bool) {
        settingsActive = show
        settingsView?.isHidden = !show
        terminalContainer.isHidden = show
        active?.surface.setOccluded(show)
        if show { hidePopup() }
        refresh()
        focusActive()
    }

}
