import AppKit

/// The Settings tab (specs/09-settings.md): native controls shown in place of
/// the terminal, opened with ⌘, or from the menu button. Every change is
/// written to the config file at once; the file watcher applies it, so the
/// file stays the one source of truth.
final class SettingsView: NSView {
    private let scroll = NSScrollView()
    private let document = FlippedView()
    private let stack = NSStackView()
    private var labels: [NSTextField] = []
    private var notes: [NSTextField] = []
    private var headers: [NSTextField] = []
    private var separators: [NSBox] = []

    private let themes = ThemePickerView()
    private let fontSize = NSTextField(labelWithString: "")
    private let fontStepper = NSStepper()
    private let opacity = NSSlider(value: 0.9, minValue: 0.5, maxValue: 1, target: nil, action: nil)
    private let opacityValue = NSTextField(labelWithString: "")
    private let tabs = NSSegmentedControl(labels: AppConfig.TabsPosition.allCases.map { $0.rawValue.capitalized },
                                          trackingMode: .selectOne, target: nil, action: nil)
    private let hotkeyEnabled = NSSwitch()
    private let shortcut = ShortcutRecorder()
    private var position: NSSegmentedControl!
    private let hideOnBlur = NSSwitch()
    private let dock = NSPopUpButton()
    private let shell = NSPopUpButton()
    private let smartInput = NSSwitch()
    private let launchAtLogin = NSSwitch()
    private let version = NSTextField(labelWithString: "")

    /// Width of the column of labels, and of the whole settings column.
    private static let labelWidth: CGFloat = 170
    private static let maxWidth: CGFloat = 640

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        build()
        load()
        applyTheme()
        NotificationCenter.default.addObserver(self, selector: #selector(configChanged), name: .terminalThemeChanged, object: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        Theme.current.chromeBackground.setFill()
        bounds.fill()
    }

    @objc private func configChanged() {
        load()
        applyTheme()
    }

    // MARK: Layout

    private func build() {
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        let width = stack.widthAnchor.constraint(equalToConstant: Self.maxWidth)
        width.priority = .defaultHigh
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -32),
            stack.centerXAnchor.constraint(equalTo: document.centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: document.leadingAnchor, constant: 28),
            width,
        ])

        let title = NSTextField(labelWithString: "Settings")
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        headers.append(title)
        add(title)

        // Appearance
        section("Appearance")
        themes.onPick = { AppConfig.update("theme", to: $0) }
        add(themes, fullWidth: true)
        stack.setCustomSpacing(18, after: themes)

        fontStepper.minValue = ConfigStore.zoomRange.lowerBound
        fontStepper.maxValue = ConfigStore.zoomRange.upperBound
        fontStepper.increment = 1
        fontStepper.target = self; fontStepper.action = #selector(fontChanged)
        fontSize.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        let font = NSStackView(views: [fontSize, fontStepper])
        font.spacing = 6
        row("Font size", font, note: "Each launch starts at this size; ⌘+ and ⌘− zoom until you quit.")
        opacity.target = self; opacity.action = #selector(opacityChanged)
        opacity.isContinuous = true
        opacity.widthAnchor.constraint(equalToConstant: 200).isActive = true
        opacityValue.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        let opacityRow = NSStackView(views: [opacity, opacityValue])
        opacityRow.spacing = 10
        row("Opacity", opacityRow, note: "How much of the desktop shows through the window, blurred.")
        tabs.target = self; tabs.action = #selector(tabsChanged)
        row("Tabs", tabs)

        // Hotkey window
        section("Hotkey window")
        hotkeyEnabled.target = self; hotkeyEnabled.action = #selector(hotkeyEnabledChanged)
        row("Hotkey window", hotkeyEnabled, note: "A terminal that drops down over any app.")
        shortcut.onChange = { AppConfig.update("hotkey", to: $0) }
        row("Shortcut", shortcut)
        position = HotkeyPositions.makeControl(target: self, action: #selector(positionChanged))
        row("Position", position)
        hideOnBlur.target = self; hideOnBlur.action = #selector(hideOnBlurChanged)
        row("Hide on blur", hideOnBlur, note: "Hides it when you click another app. Off: it stays until you press the shortcut again.")

        // General
        section("General")
        for path in Shells.available() {
            let login = path == Shells.login ? "  (login shell)" : ""
            shell.addItem(withTitle: "\(Shells.name(path))\(login)  —  \(path)")
            shell.lastItem?.representedObject = path
        }
        shell.target = self; shell.action = #selector(shellChanged)
        row("Shell", shell, note: "New tabs start with it. Smart input and command blocks need zsh for now.")
        for (title, value) in [("Only while a window is open", "auto"), ("Always", "always"), ("Never", "never")] {
            dock.addItem(withTitle: title)
            dock.lastItem?.representedObject = value
        }
        dock.target = self; dock.action = #selector(dockChanged)
        row("Show in Dock and ⌘⇥", dock, note: "With the hotkey window alone, the app stays out of the Dock and the app switcher.")
        smartInput.target = self; smartInput.action = #selector(smartInputChanged)
        row("Smart input", smartInput, note: "Edit commands with the mouse, with suggestions and completion.")
        launchAtLogin.target = self; launchAtLogin.action = #selector(launchChanged)
        row("Open at login", launchAtLogin)

        // About
        section("About")
        let check = button("Check for Updates…", #selector(AppDelegate.checkForUpdates(_:)))
        let versionRow = NSStackView(views: [version, check])
        versionRow.spacing = 12
        row("Version", versionRow)
        let actions = NSStackView(views: [
            button("Show Onboarding…", #selector(AppDelegate.showOnboarding(_:))),
            button("Send Feedback…", #selector(AppDelegate.sendFeedback(_:))),
            button("Open Config File…", #selector(AppDelegate.openConfig(_:))),
        ])
        actions.spacing = 8
        row("", actions)
    }

    private func add(_ view: NSView, fullWidth: Bool = false) {
        stack.addArrangedSubview(view)
        if fullWidth { view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
    }

    private func section(_ title: String) {
        let line = NSBox()
        line.boxType = .custom
        line.borderWidth = 0
        line.fillColor = Theme.current.separator
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        separators.append(line)
        add(line, fullWidth: true)
        stack.setCustomSpacing(16, after: line)
        let header = NSTextField(labelWithString: title)
        header.font = .systemFont(ofSize: 13, weight: .semibold)
        headers.append(header)
        add(header)
        stack.setCustomSpacing(12, after: header)
    }

    private func row(_ title: String, _ control: NSView, note: String? = nil) {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13)
        label.alignment = .right
        label.widthAnchor.constraint(equalToConstant: Self.labelWidth).isActive = true
        labels.append(label)
        var right: NSView = control
        if let note {
            let n = NSTextField(wrappingLabelWithString: note)
            n.font = .systemFont(ofSize: 11.5)
            n.preferredMaxLayoutWidth = Self.maxWidth - Self.labelWidth - 16
            notes.append(n)
            let v = NSStackView(views: [control, n])
            v.orientation = .vertical
            v.alignment = .leading
            v.spacing = 5
            right = v
        }
        let r = NSStackView(views: [label, right])
        r.alignment = .firstBaseline
        r.spacing = 16
        // Controls without a baseline (switches, the recorder) line up by centre.
        if control is NSSwitch || control is ShortcutRecorder { r.alignment = note == nil ? .centerY : .top }
        add(r)
    }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        let b = NSButton(title: title, target: NSApp.delegate, action: action)
        b.bezelStyle = .rounded
        b.controlSize = .regular
        return b
    }

    /// Native controls follow the terminal theme: dark controls on a dark theme.
    private func applyTheme() {
        let theme = Theme.current
        appearance = NSAppearance(named: theme.background.brightness < 0.5 ? .darkAqua : .aqua)
        for h in headers { h.textColor = theme.foreground }
        for l in labels { l.textColor = theme.foreground.withAlphaComponent(0.75) }
        for n in notes { n.textColor = theme.dim }
        for s in separators { s.fillColor = theme.separator }
        fontSize.textColor = theme.foreground
        opacityValue.textColor = theme.foreground
        version.textColor = theme.foreground
        themes.textColor = theme.foreground
        needsDisplay = true
    }

    // MARK: Values

    private func load() {
        let store = ConfigStore.shared
        let config = store.config
        themes.selected = config.theme
        fontStepper.doubleValue = store.baseFontSize
        fontSize.stringValue = "\(Int(store.baseFontSize)) pt"
        if !opacityDragging {
            opacity.doubleValue = Theme.current.opacity
            opacityValue.stringValue = Self.percent(Theme.current.opacity)
        }
        tabs.selectedSegment = AppConfig.TabsPosition.allCases.firstIndex(of: config.tabsPosition) ?? 0
        hotkeyEnabled.state = config.hotkeyEnabled ? .on : .off
        shortcut.spec = config.hotkey
        shortcut.isEnabled = config.hotkeyEnabled
        position.selectedSegment = HotkeyPositions.all.firstIndex(of: config.hotkeyPosition) ?? 0
        position.isEnabled = config.hotkeyEnabled
        hideOnBlur.state = config.hotkeyAutohide ? .on : .off
        hideOnBlur.isEnabled = config.hotkeyEnabled
        dock.selectItem(at: dock.itemArray.firstIndex { $0.representedObject as? String == config.dockIcon.rawValue } ?? 0)
        let current = Shells.resolved(config.shell)
        if let i = shell.itemArray.firstIndex(where: { $0.representedObject as? String == current }) { shell.selectItem(at: i) }
        smartInput.state = config.smartInput ? .on : .off
        launchAtLogin.state = config.launchAtLogin ? .on : .off
        version.stringValue = AppInfo.isReleaseBuild ? AppInfo.version : "\(AppInfo.version) (local build)"
    }

    @objc private func fontChanged() {
        let size = Int(fontStepper.doubleValue)
        fontSize.stringValue = "\(size) pt"
        AppConfig.update("font-size", to: "\(size)")
    }

    private var opacityDragging = false

    private static func percent(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }

    /// The label follows the knob live; the file is written once, on release
    /// (each write reloads the config).
    @objc private func opacityChanged() {
        let value = (opacity.doubleValue * 100).rounded() / 100
        opacityValue.stringValue = Self.percent(value)
        let released = NSApp.currentEvent?.type == .leftMouseUp || NSApp.currentEvent?.type == .keyDown
        opacityDragging = !released
        if released { AppConfig.update("background-opacity", to: String(format: "%.2f", value)) }
    }

    @objc private func tabsChanged() {
        AppConfig.update("tabs-position", to: AppConfig.TabsPosition.allCases[tabs.selectedSegment].rawValue)
    }

    @objc private func hotkeyEnabledChanged() {
        let on = hotkeyEnabled.state == .on
        shortcut.isEnabled = on
        position.isEnabled = on
        hideOnBlur.isEnabled = on
        AppConfig.update("hotkey-enabled", to: on ? "true" : "false")
    }

    @objc private func hideOnBlurChanged() {
        AppConfig.update("hotkey-autohide", to: hideOnBlur.state == .on ? "true" : "false")
    }

    @objc private func positionChanged() {
        AppConfig.update("hotkey-position", to: HotkeyPositions.all[position.selectedSegment].rawValue)
    }

    @objc private func dockChanged() {
        guard let value = dock.selectedItem?.representedObject as? String else { return }
        AppConfig.update("dock-icon", to: value)
    }

    @objc private func shellChanged() {
        guard let path = shell.selectedItem?.representedObject as? String else { return }
        Shells.choose(path)
    }

    @objc private func smartInputChanged() {
        AppConfig.update("smart-input", to: smartInput.state == .on ? "true" : "false")
    }

    @objc private func launchChanged() {
        AppConfig.update("launch-at-login", to: launchAtLogin.state == .on ? "true" : "false")
    }
}

class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
