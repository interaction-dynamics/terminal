import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windows: [NormalWindowController] = []
    private var dropdown: HotkeyWindowController!
    private var hotKey: HotKey?
    private var appearanceObservation: NSKeyValueObservation?
    private var layoutObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let config = ConfigStore.shared
        config.load()
        config.setDark(Self.systemIsDark)
        TerminalEngine.shared.start(configText: config.ghosttyConfigText)
        updateColorScheme()
        Theme.current = Theme.make()

        if config.config.historyImport { HistoryStore.shared.importShellHistoryOnce() }

        NSApp.mainMenu = MainMenu.build()
        dropdown = HotkeyWindowController()
        registerHotKey()
        // Punctuation keys move between layouts: look the key up again.
        layoutObserver = HotKey.onLayoutChange { [weak self] in self?.registerHotKey() }
        applyLaunchAtLogin()
        config.onReload = { [weak self] in
            self?.registerHotKey()
            self?.applyLaunchAtLogin()
            NotificationCenter.default.post(name: .terminalThemeChanged, object: nil)
        }

        appearanceObservation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            DispatchQueue.main.async { self?.updateColorScheme() }
        }

        newWindow(nil)
        // Release builds only: one check at launch (if a day old), then daily.
        Updater.shared.start()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if windows.isEmpty { newWindow(nil) }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private static var systemIsDark: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private func updateColorScheme() {
        let dark = Self.systemIsDark
        TerminalEngine.shared.setColorScheme(dark: dark)
        if ConfigStore.shared.setDark(dark) {
            NotificationCenter.default.post(name: .terminalThemeChanged, object: nil)
        }
    }

    private func registerHotKey() {
        hotKey = nil
        let spec = ConfigStore.shared.config.hotkey
        hotKey = HotKey(spec: spec) { [weak self] in self?.dropdown.toggle() }
        if hotKey == nil { NSLog("Could not register hotkey % %@", spec, HotKey.lastError ?? "unknown error") }
    }

    private func applyLaunchAtLogin() {
        let service = SMAppService.mainApp
        let want = ConfigStore.shared.config.launchAtLogin
        if want, service.status != .enabled { try? service.register() }
        if !want, service.status == .enabled { try? service.unregister() }
    }

    // MARK: Current window

    private var current: TerminalWindowController? {
        if let key = NSApp.keyWindow {
            if key === dropdown.panel { return dropdown }
            if let w = windows.first(where: { $0.window === key }) { return w }
        }
        return windows.first
    }

    // MARK: Menu actions

    @objc func newWindow(_ sender: Any?) {
        let wc = NormalWindowController(cwd: current?.content.active?.cwd)
        wc.onClose = { [weak self] w in self?.windows.removeAll { $0 === w } }
        windows.append(wc)
        wc.show()
    }

    @objc func newTab(_ sender: Any?) {
        guard let c = current else { newWindow(nil); return }
        c.content.newTab()
    }

    @objc func closeTab(_ sender: Any?) { current?.content.closeActiveTab() }

    @objc func closeWindow(_ sender: Any?) {
        guard let c = current else { return }
        if c === dropdown { dropdown.hide() } else { c.window?.performClose(nil) }
    }

    @objc func nextTab(_ sender: Any?) { current?.content.selectNext(1) }
    @objc func previousTab(_ sender: Any?) { current?.content.selectNext(-1) }

    @objc func selectTab(_ sender: NSMenuItem) {
        guard let c = current else { return }
        let i = sender.tag == 9 ? c.content.sessions.count - 1 : sender.tag - 1
        c.content.select(i)
    }

    @objc func toggleDropdown(_ sender: Any?) { dropdown.toggle() }

    @objc func clearScreen(_ sender: Any?) { current?.content.active?.surface.sendKey(.clearScreen) }

    // Zoom applies to every window and to the app's own chrome.
    @objc func increaseFontSize(_ sender: Any?) { ConfigStore.shared.zoom(by: 1) }
    @objc func decreaseFontSize(_ sender: Any?) { ConfigStore.shared.zoom(by: -1) }
    @objc func resetFontSize(_ sender: Any?) { ConfigStore.shared.zoom(by: 0) }

    /// Settings popover over the current window (specs/09-settings.md).
    @objc func openSettings(_ sender: Any?) {
        if current == nil { newWindow(nil) }
        current?.content.showSettings()
    }

    @objc func openConfig(_ sender: Any?) {
        AppConfig.writeStarterIfMissing()
        NSWorkspace.shared.open(AppConfig.fileURL)
    }
}
