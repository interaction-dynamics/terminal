import AppKit

/// Content of a terminal window (normal or hotkey): title strip with the
/// settings gear, the tabs (sidebar or top bar), the active tab's terminal,
/// and the smart input pinned at the bottom.
final class TerminalContentController: NSObject, SmartTextViewDelegate {
    let root = ContentRootView()
    let titleBar = TitleBarView()
    let tabBar = TabBarView()
    let sidebar = TabSidebarView()
    let gear = NSButton()
    let input = InputAreaView()
    private let terminalContainer = NSView()
    private let popup = SuggestionPopup()

    private(set) var sessions: [Session] = []
    private(set) var activeIndex = 0
    var active: Session? { sessions.indices.contains(activeIndex) ? sessions[activeIndex] : nil }
    var onEmpty: (() -> Void)?
    var onTitleChange: ((String) -> Void)?

    private var bells = Set<String>()
    private var historyCursor: Int?
    private var historyDraft = ""
    private var suggestGeneration = 0
    private var completions: [Completion] = []
    private var completionRange: Range<String.Index>?
    private enum PopupMode { case none, completion, history }
    private var popupMode = PopupMode.none
    private var historyMatches: [String] = []

    init(leadingInset: CGFloat) {
        super.init()
        tabBar.leadingInset = leadingInset
        root.titleBar = titleBar
        root.tabBar = tabBar
        root.sidebar = sidebar
        root.gear = gear
        root.terminal = terminalContainer
        root.input = input
        root.addSubview(terminalContainer)
        root.addSubview(titleBar)
        root.addSubview(tabBar)
        root.addSubview(sidebar)
        root.addSubview(input)
        root.addSubview(gear)
        input.textView.smartDelegate = self
        tabBar.onSelect = { [weak self] i in self?.select(i) }
        tabBar.onClose = { [weak self] i in self?.closeTab(at: i) }
        tabBar.onNew = { [weak self] in self?.newTab() }
        sidebar.onSelect = { [weak self] i in self?.select(i) }
        sidebar.onClose = { [weak self] i in self?.closeTab(at: i) }
        sidebar.onNew = { [weak self] in self?.newTab() }
        gear.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        gear.isBordered = false
        gear.imageScaling = .scaleProportionallyDown
        gear.toolTip = "Settings (⌘,)"
        gear.target = self
        gear.action = #selector(showSettings)
        gear.contentTintColor = Theme.current.dim
        popup.onPick = { [weak self] i in self?.pickPopup(i) }
        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: .terminalThemeChanged, object: nil)
    }

    @objc func themeChanged() {
        Theme.current = Theme.make()
        gear.contentTintColor = Theme.current.dim
        root.needsLayout = true
        for v in [root, titleBar, tabBar, sidebar] as [NSView] { v.needsDisplay = true }
        input.applyTheme()
    }

    @objc func showSettings() {
        SettingsPopover.shared.toggle(from: gear)
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
        guard sessions.indices.contains(index) else { return }
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
        s.surface.setOccluded(false)
        input.textView.text = s.draft
        historyCursor = nil
        hidePopup()
        refresh()
        focusActive()
    }

    func selectNext(_ delta: Int) {
        guard !sessions.isEmpty else { return }
        select((activeIndex + delta + sessions.count) % sessions.count)
    }

    func closeActiveTab() {
        guard let s = active else { return }
        s.surface.close()
        remove(s)
    }

    func closeTab(at index: Int) {
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
        select(next)
    }

    private func sessionChanged(_ s: Session) {
        // A background tab that finished a command gets a dot until it is viewed
        // (not one that just started its shell).
        if s !== active, s.state == .atPrompt, s.previousCommand != nil { bells.insert(s.id) }
        refresh()
        if s === active, s.state == .atPrompt, root.window?.firstResponder === s.surface.view {
            focusActive()
        }
    }

    /// Updates tab labels, the prompt line and which part has the keyboard.
    func refresh() {
        let items = sessions.enumerated().map { i, s in
            TabBarView.Item(label: s.label, detail: s.displayDirectory, active: i == activeIndex, bell: bells.contains(s.id))
        }
        tabBar.items = items
        sidebar.items = items
        guard let s = active else { return }
        onTitleChange?(s.label)
        titleBar.title = s.label
        let showInput = s.acceptsInput && ConfigStore.shared.config.smartInput
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
        if !input.isHidden {
            window.makeFirstResponder(input.textView)
        } else {
            window.makeFirstResponder(s.surface.view)
        }
    }

    func setOccluded(_ occluded: Bool) {
        active?.surface.setOccluded(occluded)
        if occluded { hidePopup() }
    }

    // MARK: SmartTextViewDelegate

    func smartTextSubmit(_ view: SmartTextView) {
        guard let s = active else { return }
        let command = view.string
        view.ghost = ""
        hidePopup()
        historyCursor = nil
        view.text = ""
        view.undoManager?.removeAllActions()
        s.submit(command)
        refresh()
        window(makeFirstResponder: s.surface.view)
    }

    private func window(makeFirstResponder view: NSView) {
        root.window?.makeFirstResponder(view)
    }

    func smartTextHistory(_ view: SmartTextView, older: Bool) -> Bool {
        let recent = HistoryStore.shared.recentSnapshot
        guard !recent.isEmpty else { return false }
        if historyCursor == nil {
            guard older else { return false }
            historyDraft = view.string
        }
        let current = historyCursor ?? recent.count
        // Only walk through commands starting with what was typed (like zsh's up-line-or-search).
        let prefix = historyDraft
        var i = current
        repeat {
            i += older ? -1 : 1
        } while i >= 0 && i < recent.count && !prefix.isEmpty && !recent[i].hasPrefix(prefix)
        if i < 0 { return true }
        if i >= recent.count {
            historyCursor = nil
            view.text = historyDraft
            return true
        }
        historyCursor = i
        view.text = recent[i]
        view.ghost = ""
        return true
    }

    func smartTextTab(_ view: SmartTextView) {
        guard let s = active else { return }
        let line = view.string
        let cursorOffset = view.selectedRange().location
        let cursor = String.Index(utf16Offset: cursorOffset, in: line)
        Completer.shared.complete(line: line, cursor: cursor, cwd: s.cwd) { [weak self] items in
            guard let self, view.string == line else { return }
            let ctx = WordContext.parse(line, cursor: cursor)
            self.completions = items
            self.completionRange = ctx.range
            if items.count == 1 {
                self.apply(items[0])
            } else if !items.isEmpty {
                // Fill the common prefix first, like a shell.
                let common = Self.commonPrefix(items.map(\.replacement))
                let currentWord = String(line[ctx.range])
                if common.count > currentWord.count, !common.hasSuffix(" ") {
                    self.apply(Completion(replacement: common, display: common, kind: .file))
                    self.completionRange = WordContext.parse(view.string, cursor: view.string.index(view.string.startIndex, offsetBy: (String(line[..<ctx.range.lowerBound]) + common).count)).range
                }
                self.popupMode = .completion
                self.popup.show(rows: items.map { SuggestionPopup.Row(title: $0.display, detail: Self.kindLabel($0.kind)) },
                                above: view.caretScreenRect, in: view.window!, header: nil)
            } else {
                NSSound.beep()
            }
        }
    }

    private static func kindLabel(_ k: Completion.Kind) -> String {
        switch k {
        case .folder: return "folder"
        case .file: return "file"
        case .command: return "command"
        case .branch: return "branch"
        case .script: return "script"
        case .subcommand: return "subcommand"
        case .history: return "history"
        }
    }

    static func commonPrefix(_ strings: [String]) -> String {
        guard var prefix = strings.first else { return "" }
        for s in strings.dropFirst() {
            while !s.hasPrefix(prefix) { prefix.removeLast() }
        }
        return prefix
    }

    private func apply(_ c: Completion) {
        let tv = input.textView
        let line = tv.string
        guard let range = completionRange, range.upperBound <= line.endIndex else { return }
        let ns = NSRange(range, in: line)
        tv.insertText(c.replacement, replacementRange: ns)
        hidePopup()
    }

    func smartTextHistorySearch(_ view: SmartTextView) {
        popupMode = .history
        updateHistorySearch()
    }

    private func updateHistorySearch() {
        guard let s = active else { return }
        let query = input.textView.string
        let ctx = s.rankContext
        let gen = suggestGeneration
        HistoryStore.shared.queue.async { [weak self] in
            let matches = Ranker.fuzzyMatches(query, in: HistoryStore.shared.index.stats, ctx: ctx)
            DispatchQueue.main.async {
                guard let self, self.popupMode == .history, gen == self.suggestGeneration, let window = self.input.window else { return }
                self.historyMatches = matches
                if matches.isEmpty { self.popup.hide(); return }
                self.popup.show(rows: matches.map { SuggestionPopup.Row(title: $0, detail: nil) },
                                above: self.input.textView.caretScreenRect, in: window,
                                header: "History  ·  ⏎ pick  ·  ⌘⌫ delete")
            }
        }
    }

    func smartTextInterrupt(_ view: SmartTextView) {
        hidePopup()
        historyCursor = nil
        view.text = ""
        view.ghost = ""
    }

    func smartTextEOF(_ view: SmartTextView) {
        active?.sendEOF()
    }

    func smartTextClearScreen(_ view: SmartTextView) {
        active?.surface.sendKey(.clearScreen)
    }

    func smartTextEscape(_ view: SmartTextView) -> Bool {
        if popup.isVisible { hidePopup(); return true }
        return false
    }

    func smartTextPopupKey(_ view: SmartTextView, _ key: SmartTextView.PopupKey) -> Bool {
        guard popup.isVisible else { return false }
        switch key {
        case .up: popup.move(-1)
        case .down, .tab: popup.move(1)
        case .accept: pickPopup(popup.selectedIndex)
        }
        return true
    }

    private func pickPopup(_ i: Int) {
        switch popupMode {
        case .completion where completions.indices.contains(i):
            apply(completions[i])
        case .history where historyMatches.indices.contains(i):
            input.textView.text = historyMatches[i]
            hidePopup()
        default:
            hidePopup()
        }
        root.window?.makeFirstResponder(input.textView)
    }

    /// ⌘⌫ in the history popup deletes the selected command from history.
    func smartTextDeleteHistoryEntry(_ view: SmartTextView) -> Bool {
        guard popupMode == .history, popup.isVisible, historyMatches.indices.contains(popup.selectedIndex) else { return false }
        HistoryStore.shared.delete(command: historyMatches[popup.selectedIndex])
        updateHistorySearch()
        return true
    }

    private func hidePopup() {
        popup.hide()
        popupMode = .none
    }

    func smartTextDidChange(_ view: SmartTextView) {
        suggestGeneration += 1
        root.needsLayout = true
        Completer.shared.warmUp()
        if popupMode == .completion { hidePopup() }
        if popupMode == .history { updateHistorySearch() }
        updateGhost()
    }

    /// Ghost suggestion off the main thread; a newer keystroke cancels older results.
    private func updateGhost() {
        let tv = input.textView
        let text = tv.string
        guard let s = active, tv.caretAtEnd, !text.isEmpty, !text.contains("\n") else { tv.ghost = ""; return }
        let ctx = s.rankContext
        let gen = suggestGeneration
        HistoryStore.shared.bestMatch(text, ctx: ctx) { [weak self] best in
            guard let self, gen == self.suggestGeneration, tv.string == text else { return }
            tv.ghost = best.map { String(decoding: $0.utf8.dropFirst(text.utf8.count), as: UTF8.self) } ?? ""
        }
    }
}

/// Lays out title strip / tabs / terminal / input, and paints the translucent
/// background behind the title strip.
final class ContentRootView: NSView {
    weak var titleBar: TitleBarView?
    weak var tabBar: TabBarView?
    weak var sidebar: TabSidebarView?
    weak var gear: NSView?
    weak var terminal: NSView?
    weak var input: InputAreaView?

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        let config = ConfigStore.shared.config
        let titleH = Theme.tabBarHeight
        let g = Theme.gearSize
        titleBar?.frame = NSRect(x: 0, y: 0, width: bounds.width, height: titleH)
        // The gear is always there, top-right, whatever the tab position.
        gear?.frame = NSRect(x: bounds.width - g - 10, y: (titleH - g) / 2, width: g, height: g)

        var body = NSRect(x: 0, y: titleH, width: bounds.width, height: max(0, bounds.height - titleH))
        let side = config.tabsPosition != .top
        tabBar?.isHidden = side
        sidebar?.isHidden = !side
        titleBar?.showsTitle = side
        if side {
            let w = min(config.tabsWidth, bounds.width / 2)
            let left = config.tabsPosition == .left
            sidebar?.edge = config.tabsPosition
            sidebar?.frame = NSRect(x: left ? 0 : bounds.width - w, y: titleH, width: w, height: body.height)
            body.size.width -= w
            if left { body.origin.x = w }
        } else {
            tabBar?.frame = NSRect(x: 0, y: 0, width: bounds.width - g - 20, height: titleH)
        }

        var inputH: CGFloat = 0
        if let input, !input.isHidden {
            inputH = input.preferredHeight
            input.frame = NSRect(x: body.minX, y: body.maxY - inputH, width: body.width, height: inputH)
        }
        terminal?.frame = NSRect(x: body.minX, y: body.minY, width: body.width, height: max(0, body.height - inputH))
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        // The terminal draws its own (translucent) background; paint the same
        // colour under the tab bar so it reads as one surface. The input area
        // paints its own.
        let theme = Theme.current
        theme.chromeBackground.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: Theme.tabBarHeight).fill()
    }
}
