import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windows: [NormalWindowController] = []
    private var dropdown: HotkeyWindowController!
    private var hotKey: HotKey?
    private var appearanceObservation: NSKeyValueObservation?
    private var layoutObserver: NSObjectProtocol?
    private var recordingShortcut = false
    private static let onboardingDoneKey = "onboarding.done"

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
            guard let self else { return }
            self.registerHotKey()
            if !config.config.hotkeyEnabled { self.dropdown.hide(restoreFocus: false) }
            self.applyLaunchAtLogin()
            self.updateDockIcon()
            NotificationCenter.default.post(name: .terminalThemeChanged, object: nil)
        }
        // A shortcut recorder is listening: let it have the current hotkey too.
        NotificationCenter.default.addObserver(forName: .terminalRecordingShortcut, object: nil, queue: .main) { [weak self] note in
            self?.recordingShortcut = note.object as? Bool ?? false
            self?.registerHotKey()
        }

        appearanceObservation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            DispatchQueue.main.async { self?.updateColorScheme() }
        }

        newWindow(nil)
        if !UserDefaults.standard.bool(forKey: Self.onboardingDoneKey) { showOnboarding(nil) }
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
        guard ConfigStore.shared.config.hotkeyEnabled, !recordingShortcut else { return }
        let spec = ConfigStore.shared.config.hotkey
        hotKey = HotKey(spec: spec) { [weak self] in self?.dropdown.toggle() }
        if hotKey == nil { NSLog("Could not register hotkey % %@", spec, HotKey.lastError ?? "unknown error") }
    }

    /// Dock icon and ⌘⇥ switcher (specs/09-settings.md). `auto`: shown while a
    /// normal window is open, hidden when only the hotkey window is in use.
    private func updateDockIcon() {
        let config = ConfigStore.shared.config
        let show: Bool
        switch config.dockIcon {
        case .always: show = true
        case .never: show = false
        case .auto: show = !windows.isEmpty || !config.hotkeyEnabled
        }
        let policy: NSApplication.ActivationPolicy = show ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        // Changing the policy can drop the app out of the front; keep a visible window there.
        if NSApp.windows.contains(where: { $0.isVisible && $0.canBecomeKey }) {
            DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
        }
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
        wc.onClose = { [weak self] w in
            self?.windows.removeAll { $0 === w }
            self?.updateDockIcon()
        }
        windows.append(wc)
        updateDockIcon()
        wc.show()
        NSApp.activate(ignoringOtherApps: true)
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
        let i = sender.tag == 9 ? c.content.tabCount - 1 : sender.tag - 1
        c.content.select(i)
    }

    @objc func toggleDropdown(_ sender: Any?) { dropdown.toggle() }

    @objc func clearScreen(_ sender: Any?) { current?.content.active?.surface.sendKey(.clearScreen) }

    // Zoom applies to every window and to the app's own chrome.
    @objc func increaseFontSize(_ sender: Any?) { ConfigStore.shared.zoom(by: 1) }
    @objc func decreaseFontSize(_ sender: Any?) { ConfigStore.shared.zoom(by: -1) }
    @objc func resetFontSize(_ sender: Any?) { ConfigStore.shared.zoom(by: 0) }

    /// The Settings tab in the current window (specs/09-settings.md).
    @objc func openSettings(_ sender: Any?) {
        if current == nil { newWindow(nil) }
        current?.content.openSettingsTab()
    }

    @objc func showAbout(_ sender: Any?) {
        AboutWindow.shared.show(over: NSApp.keyWindow ?? current?.window)
    }

    @objc func showOnboarding(_ sender: Any?) {
        // The dropdown floats above normal windows: get it out of the way.
        dropdown.hide(restoreFocus: false)
        Onboarding.shared.show { UserDefaults.standard.set(true, forKey: Self.onboardingDoneKey) }
    }

    @objc func sendFeedback(_ sender: Any?) { NSWorkspace.shared.open(AppInfo.feedbackURL) }

    @objc func checkForUpdates(_ sender: Any?) { Updater.shared.checkFromMenu(sender) }

    @objc func openConfig(_ sender: Any?) {
        AppConfig.writeStarterIfMissing()
        NSWorkspace.shared.open(AppConfig.fileURL)
    }
}
