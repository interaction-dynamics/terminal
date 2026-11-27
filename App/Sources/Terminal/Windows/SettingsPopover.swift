import AppKit

/// Settings, as a popover over the terminal (specs/09-settings.md). Opened by
/// the gear in the title bar or ⌘,; Esc or a click outside closes it.
/// Every change is written to the config file at once; the file watcher then
/// applies it, so the file stays the one source of truth.
final class SettingsPopover: NSObject, NSPopoverDelegate {
    static let shared = SettingsPopover()

    private let popover = NSPopover()
    private let theme = NSPopUpButton()
    private let tabs = NSSegmentedControl(labels: AppConfig.TabsPosition.allCases.map { $0.rawValue.capitalized },
                                          trackingMode: .selectOne, target: nil, action: nil)
    private let fontSize = NSTextField(labelWithString: "")
    private let fontStepper = NSStepper()
    private let hotkey = NSTextField()
    private let smartInput = NSButton(checkboxWithTitle: "Smart input", target: nil, action: nil)
    private let launchAtLogin = NSButton(checkboxWithTitle: "Open at login", target: nil, action: nil)

    var isShown: Bool { popover.isShown }

    private override init() {
        super.init()
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        let vc = NSViewController()
        let view = makeView()
        view.layoutSubtreeIfNeeded()
        view.setFrameSize(view.fittingSize)
        vc.view = view
        vc.preferredContentSize = view.fittingSize
        popover.contentViewController = vc
        NotificationCenter.default.addObserver(self, selector: #selector(load), name: .terminalThemeChanged, object: nil)
    }

    func toggle(from view: NSView) {
        if popover.isShown { popover.performClose(nil); return }
        load()
        if let content = popover.contentViewController?.view {
            content.layoutSubtreeIfNeeded()
            popover.contentSize = content.fittingSize
        }
        popover.appearance = NSAppearance(named: Theme.current.background.brightness < 0.5 ? .darkAqua : .aqua)
        popover.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }

    // MARK: Layout

    private func makeView() -> NSView {
        for (name, title, _) in AppConfig.builtinThemes {
            theme.addItem(withTitle: title)
            theme.lastItem?.representedObject = name
        }
        theme.target = self; theme.action = #selector(themeChanged)

        tabs.target = self; tabs.action = #selector(tabsChanged)

        fontStepper.minValue = ConfigStore.zoomRange.lowerBound
        fontStepper.maxValue = ConfigStore.zoomRange.upperBound
        fontStepper.increment = 1
        fontStepper.target = self; fontStepper.action = #selector(fontChanged)
        fontSize.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let fontRow = NSStackView(views: [fontSize, fontStepper])
        fontRow.spacing = 6

        hotkey.placeholderString = "cmd+shift+backslash"
        hotkey.target = self; hotkey.action = #selector(hotkeyChanged)
        hotkey.widthAnchor.constraint(equalToConstant: 190).isActive = true

        smartInput.target = self; smartInput.action = #selector(smartInputChanged)
        launchAtLogin.target = self; launchAtLogin.action = #selector(launchChanged)

        let open = NSButton(title: "Open config file…", target: self, action: #selector(openFile))
        open.bezelStyle = .rounded

        let grid = NSGridView(views: [
            [label("Theme"), theme],
            [label("Tabs"), tabs],
            [label("Font size"), fontRow],
            [label("Hotkey"), hotkey],
            [NSGridCell.emptyContentView, smartInput],
            [NSGridCell.emptyContentView, launchAtLogin],
        ])
        grid.rowSpacing = 10
        grid.columnSpacing = 12
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).width = 190
        grid.rowAlignment = .firstBaseline

        let title = NSTextField(labelWithString: "Settings")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        let stack = NSStackView(views: [title, grid, open])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)
        open.leadingAnchor.constraint(equalTo: grid.leadingAnchor).isActive = true
        // NSStackView does not keep the trailing inset for leading-aligned rows.
        grid.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -18).isActive = true
        return stack
    }

    private func label(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.textColor = .secondaryLabelColor
        return l
    }

    // MARK: Values

    @objc private func load() {
        let store = ConfigStore.shared
        let config = store.config
        let current = config.theme
        if let item = theme.itemArray.first(where: { $0.representedObject as? String == current }) {
            theme.select(item)
        } else {
            // A Ghostty theme typed in the file: show it as is.
            theme.itemArray.filter { $0.tag == 1 }.forEach { theme.removeItem(at: theme.index(of: $0)) }
            theme.addItem(withTitle: current)
            theme.lastItem?.representedObject = current
            theme.lastItem?.tag = 1
            theme.select(theme.lastItem)
        }
        tabs.selectedSegment = AppConfig.TabsPosition.allCases.firstIndex(of: config.tabsPosition) ?? 0
        fontStepper.doubleValue = store.baseFontSize
        fontSize.stringValue = "\(Int(store.baseFontSize)) pt"
        hotkey.stringValue = config.hotkey
        hotkey.textColor = .labelColor
        smartInput.state = config.smartInput ? .on : .off
        launchAtLogin.state = config.launchAtLogin ? .on : .off
    }

    @objc private func themeChanged() {
        guard let name = theme.selectedItem?.representedObject as? String else { return }
        AppConfig.update("theme", to: name)
    }

    @objc private func tabsChanged() {
        let position = AppConfig.TabsPosition.allCases[tabs.selectedSegment]
        AppConfig.update("tabs-position", to: position.rawValue)
    }

    @objc private func fontChanged() {
        let size = Int(fontStepper.doubleValue)
        fontSize.stringValue = "\(size) pt"
        AppConfig.update("font-size", to: "\(size)")
    }

    @objc private func hotkeyChanged() {
        let spec = hotkey.stringValue.trimmingCharacters(in: .whitespaces)
        guard HotKey.parse(spec) != nil else { hotkey.textColor = .systemRed; return }
        hotkey.textColor = .labelColor
        AppConfig.update("hotkey", to: spec)
    }

    @objc private func smartInputChanged() {
        AppConfig.update("smart-input", to: smartInput.state == .on ? "true" : "false")
    }

    @objc private func launchChanged() {
        AppConfig.update("launch-at-login", to: launchAtLogin.state == .on ? "true" : "false")
    }

    @objc private func openFile() {
        popover.performClose(nil)
        AppConfig.writeStarterIfMissing()
        NSWorkspace.shared.open(AppConfig.fileURL)
    }
}
