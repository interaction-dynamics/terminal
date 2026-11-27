import AppKit

/// Content of a terminal window (normal or hotkey): title strip with the
/// menu button, the tabs (sidebar or top bar), the active tab's terminal (or
/// the Settings tab), and the smart input pinned at the bottom.
final class TerminalContentController: NSObject, SmartTextViewDelegate {
    let root = ContentRootView()
    let titleBar = TitleBarView()
    let tabBar = TabBarView()
    let sidebar = TabSidebarView()
    let menuButton = NSButton()
    let input = InputAreaView()
    let updateBanner = UpdateBanner()
    let terminalContainer = NSView()
    var settingsView: SettingsView?
    /// The Settings tab is in the tab list (after the shells)…
    var settingsOpen = false
    /// …and is the one showing.
    var settingsActive = false
    let popup = SuggestionPopup()

    private(set) var sessions: [Session] = []
    private(set) var activeIndex = 0
    var active: Session? { sessions.indices.contains(activeIndex) ? sessions[activeIndex] : nil }
    /// Shells plus the Settings tab when it is open.
    var tabCount: Int { sessions.count + (settingsOpen ? 1 : 0) }
    var onEmpty: (() -> Void)?
    var onTitleChange: ((String) -> Void)?

    private var bells = Set<String>()
    var historyCursor: Int?
    var historyDraft = ""
    var suggestGeneration = 0
    var completions: [Completion] = []
    var completionRange: Range<String.Index>?
    enum PopupMode { case none, completion, history }
    var popupMode = PopupMode.none
    var historyMatches: [String] = []

    /// `compactChrome`: the hotkey dropdown, with no title strip; the sidebar
    /// runs from the top with + and the menu button in its first row.
    init(leadingInset: CGFloat, compactChrome: Bool = false) {
        super.init()
        tabBar.leadingInset = leadingInset
        root.compactChrome = compactChrome
        root.titleBar = titleBar
        root.tabBar = tabBar
        root.sidebar = sidebar
        root.menuButton = menuButton
        root.terminal = terminalContainer
        root.input = input
        root.banner = updateBanner
        root.addSubview(terminalContainer)
        root.addSubview(titleBar)
        root.addSubview(tabBar)
        root.addSubview(sidebar)
        root.addSubview(input)
        root.addSubview(updateBanner)
        root.addSubview(menuButton)
        updateBanner.onVisibilityChange = { [weak self] in self?.root.needsLayout = true }
        input.textView.smartDelegate = self
        tabBar.onSelect = { [weak self] i in self?.select(i) }
        tabBar.onClose = { [weak self] i in self?.closeTab(at: i) }
        tabBar.onNew = { [weak self] in self?.newTab() }
        sidebar.onSelect = { [weak self] i in self?.select(i) }
        sidebar.onClose = { [weak self] i in self?.closeTab(at: i) }
        sidebar.onNew = { [weak self] in self?.newTab() }
        menuButton.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "Menu")
        menuButton.isBordered = false
        menuButton.imageScaling = .scaleProportionallyDown
        menuButton.toolTip = "Settings, updates, about…"
        menuButton.target = self
        menuButton.action = #selector(showMenu)
        menuButton.contentTintColor = Theme.current.dim
        popup.onPick = { [weak self] i in self?.pickPopup(i) }
        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: .terminalThemeChanged, object: nil)
    }

    @objc func themeChanged() {
        Theme.current = Theme.make()
        menuButton.contentTintColor = Theme.current.dim
        root.needsLayout = true
        for v in [root, titleBar, tabBar, sidebar] as [NSView] { v.needsDisplay = true }
        refresh()
        input.applyTheme()
        updateBanner.applyTheme()
    }

    // MARK: Tabs

    func newTab(cwd: String? = nil) {
        let dir = cwd ?? active?.cwd
        let session = Session(workingDirectory: dir, smartInput: ConfigStore.shared.config.smartInput)
        session.onChange = { [weak self] s in self?.sessionChanged(s) }
        session.onClose = { [weak self] s in self?.remove(s) }
        sessions.insert(session, at: sessions.isEmpty ? 0 : activeIndex + 1)
        select(sessions.firstIndex { $0 === session }!)
    }

    func select(_ index: Int) {
        if index == sessions.count, settingsOpen { showSettings(true); return }
        guard sessions.indices.contains(index) else { return }
        if settingsActive { showSettings(false) }
        attach(index)
    }

    /// Puts shell `index` in the terminal area (behind Settings if that is showing).
    private func attach(_ index: Int) {
        if let current = active, current !== sessions[index] {
            current.draft = input.textView.string
            current.surface.view.removeFromSuperview()
            current.surface.setOccluded(true)
        }
        activeIndex = index
        let s = sessions[index]
        bells.remove(s.id)
        let view = s.surface.view
        if view.superview !== terminalContainer {
            view.frame = terminalContainer.bounds
            view.autoresizingMask = [.width, .height]
            terminalContainer.addSubview(view)
        }
        s.surface.setOccluded(settingsActive)
        input.textView.text = s.draft
        historyCursor = nil
        hidePopup()
        refresh()
        focusActive()
    }

    func selectNext(_ delta: Int) {
        guard tabCount > 0 else { return }
        let current = settingsActive ? sessions.count : activeIndex
        select((current + delta + tabCount) % tabCount)
    }

    func closeActiveTab() {
        if settingsActive { closeSettingsTab(); return }
        guard let s = active else { return }
        s.surface.close()
        remove(s)
    }

    func closeTab(at index: Int) {
        if index == sessions.count, settingsOpen { closeSettingsTab(); return }
        guard sessions.indices.contains(index) else { return }
        let s = sessions[index]
        s.surface.close()
        remove(s)
    }

    private func remove(_ session: Session) {
        guard let i = sessions.firstIndex(where: { $0 === session }) else { return }
        session.surface.view.removeFromSuperview()
        sessions.remove(at: i)
        if sessions.isEmpty {
            refresh()
            onEmpty?()
            return
        }
        activeIndex = min(activeIndex > i ? activeIndex - 1 : activeIndex, sessions.count - 1)
        let next = activeIndex
        activeIndex = -1
        attach(next)
    }

    private func sessionChanged(_ s: Session) {
        // A background tab that finished a command gets a dot until it is viewed
        // (not one that just started its shell).
        if s !== active, s.state == .atPrompt, s.previousCommand != nil { bells.insert(s.id) }
        refresh()
        if s === active, !settingsActive, s.state == .atPrompt, root.window?.firstResponder === s.surface.view {
            focusActive()
        }
    }

    /// Updates tab labels, the prompt line and which part has the keyboard.
    func refresh() {
        var items = sessions.enumerated().map { i, s in
            TabBarView.Item(label: s.label, detail: s.displayDirectory, active: !settingsActive && i == activeIndex, bell: bells.contains(s.id))
        }
        if settingsOpen {
            items.append(TabBarView.Item(label: "Settings", active: settingsActive, bell: false, symbol: "gearshape"))
        }
        tabBar.items = items
        sidebar.items = items
        guard let s = active else { return }
        let title = settingsActive ? "Settings" : s.label
        onTitleChange?(title)
        titleBar.title = title
        let showInput = !settingsActive && s.acceptsInput && ConfigStore.shared.config.smartInput
        if input.isHidden == showInput {
            input.isHidden = !showInput
            if !showInput { hidePopup() }
        }
        input.promptLine.directory = s.displayDirectory
        input.promptLine.branch = s.gitBranch
        input.promptLine.exitCode = s.lastExitCode
        input.promptLine.durationMs = s.lastDurationMs
        root.needsLayout = true
    }

    func focusActive() {
        guard let s = active, let window = root.window else { return }
        if settingsActive {
            window.makeFirstResponder(settingsView)
        } else if !input.isHidden {
            window.makeFirstResponder(input.textView)
        } else {
            window.makeFirstResponder(s.surface.view)
        }
    }

    func setOccluded(_ occluded: Bool) {
        active?.surface.setOccluded(occluded || settingsActive)
        if occluded { hidePopup() }
    }

}
