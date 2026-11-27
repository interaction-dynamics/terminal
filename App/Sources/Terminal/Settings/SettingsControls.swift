import AppKit

// Widgets shared by the Settings tab and the onboarding window.

extension NSColor {
    /// "0e0e0e" → colour. Black for anything unreadable.
    convenience init(hex: String) {
        let v = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(srgbRed: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255,
                  blue: CGFloat(v & 0xff) / 255, alpha: 1)
    }
}

// MARK: - Theme cards

/// One card per built-in theme, each a tiny terminal in that theme's colours.
/// Clicking a card calls `onPick` with the theme's name.
final class ThemePickerView: NSView {
    var selected: String? { didSet { needsDisplay = true } }
    var textColor: NSColor = .labelColor { didSet { needsDisplay = true } }
    var onPick: ((String) -> Void)?

    private let themes = AppConfig.builtinThemes.map { ($0.name, $0.title) }
    private var hovered: Int?
    private var trackingArea: NSTrackingArea?
    private static let spacing: CGFloat = 10
    private static let labelHeight: CGFloat = 22

    override var isFlipped: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 96) }
    override var mouseDownCanMoveWindow: Bool { false }

    private func cardRect(_ i: Int) -> NSRect {
        let n = CGFloat(themes.count)
        let w = min(124, (bounds.width - Self.spacing * (n - 1)) / n)
        return NSRect(x: CGFloat(i) * (w + Self.spacing), y: 2, width: w, height: bounds.height - Self.labelHeight - 4)
    }

    override func draw(_ dirtyRect: NSRect) {
        for (i, (name, title)) in themes.enumerated() {
            let r = cardRect(i)
            let path = NSBezierPath(roundedRect: r, xRadius: 8, yRadius: 8)
            NSGraphicsContext.saveGraphicsState()
            path.addClip()
            if name == "auto" {
                drawMiniTerminal(in: r, theme: "paper")
                let half = NSBezierPath()
                half.move(to: NSPoint(x: r.maxX, y: r.minY))
                half.line(to: NSPoint(x: r.maxX, y: r.maxY))
                half.line(to: NSPoint(x: r.minX, y: r.maxY))
                half.close()
                half.addClip()
                drawMiniTerminal(in: r, theme: "midnight")
            } else {
                drawMiniTerminal(in: r, theme: name)
            }
            NSGraphicsContext.restoreGraphicsState()

            let isSelected = name == selected
            if isSelected {
                let ring = NSBezierPath(roundedRect: r.insetBy(dx: -2.5, dy: -2.5), xRadius: 10, yRadius: 10)
                ring.lineWidth = 2
                NSColor.controlAccentColor.setStroke()
                ring.stroke()
            } else {
                path.lineWidth = 1
                textColor.withAlphaComponent(hovered == i ? 0.45 : 0.15).setStroke()
                path.stroke()
            }
            let p = NSMutableParagraphStyle()
            p.alignment = .center
            (title as NSString).draw(in: NSRect(x: r.minX - 4, y: r.maxY + 6, width: r.width + 8, height: 16), withAttributes: [
                .font: NSFont.systemFont(ofSize: 11.5, weight: isSelected ? .semibold : .regular),
                .foregroundColor: isSelected ? textColor : textColor.withAlphaComponent(0.7),
                .paragraphStyle: p,
            ])
        }
    }

    /// A prompt and a few "lines of output" as bars.
    private func drawMiniTerminal(in r: NSRect, theme: String) {
        guard let c = AppConfig.themePreviews[theme] else { return }
        let bg = NSColor(hex: c.bg), fg = NSColor(hex: c.fg), accent = NSColor(hex: c.accent)
        bg.setFill()
        r.fill()
        let x = r.minX + 10
        var y = r.minY + 12
        accent.setFill()
        NSBezierPath(roundedRect: NSRect(x: x, y: y, width: 6, height: 5), xRadius: 1.5, yRadius: 1.5).fill()
        fg.withAlphaComponent(0.85).setFill()
        NSBezierPath(roundedRect: NSRect(x: x + 10, y: y, width: r.width * 0.42, height: 5), xRadius: 2.5, yRadius: 2.5).fill()
        y += 12
        for w in [0.62, 0.48, 0.55] {
            fg.withAlphaComponent(0.35).setFill()
            NSBezierPath(roundedRect: NSRect(x: x, y: y, width: (r.width - 20) * w, height: 4), xRadius: 2, yRadius: 2).fill()
            y += 9
        }
        accent.setFill()
        NSBezierPath(roundedRect: NSRect(x: x, y: y + 3, width: 6, height: 5), xRadius: 1.5, yRadius: 1.5).fill()
        fg.setFill()
        NSRect(x: x + 10, y: y + 2, width: 2, height: 7).fill()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(t)
        trackingArea = t
    }

    private func index(at event: NSEvent) -> Int? {
        let p = convert(event.locationInWindow, from: nil)
        return themes.indices.first { cardRect($0).insetBy(dx: -4, dy: -4).union(cardRect($0).offsetBy(dx: 0, dy: 20)).contains(p) }
    }

    override func mouseMoved(with event: NSEvent) {
        let h = index(at: event)
        if h != hovered { hovered = h; needsDisplay = true }
    }

    override func mouseExited(with event: NSEvent) { hovered = nil; needsDisplay = true }

    override func mouseDown(with event: NSEvent) {
        guard let i = index(at: event) else { return }
        selected = themes[i].0
        onPick?(themes[i].0)
    }
}

// MARK: - Shortcut recorder

/// Shows the hotkey ("⇧⌘\"); click it, then press the new shortcut.
/// Esc cancels. While it listens, the app's own hotkey is off so it can be
/// pressed (see `.terminalRecordingShortcut`).
final class ShortcutRecorder: NSView {
    var spec = "" { didSet { needsDisplay = true } }
    var onChange: ((String) -> Void)?
    var isEnabled = true { didSet { needsDisplay = true; if !isEnabled { stop() } } }
    private var recording = false { didSet { needsDisplay = true } }
    private var rejected = false

    override var intrinsicContentSize: NSSize { NSSize(width: 170, height: 26) }
    override var acceptsFirstResponder: Bool { isEnabled }
    override var mouseDownCanMoveWindow: Bool { false }
    override var focusRingMaskBounds: NSRect { bounds }
    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6).fill()
    }

    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: r, xRadius: 6, yRadius: 6)
        (recording ? NSColor.controlAccentColor.withAlphaComponent(0.15) : NSColor.labelColor.withAlphaComponent(0.07)).setFill()
        path.fill()
        (recording ? NSColor.controlAccentColor : (rejected ? NSColor.systemRed : NSColor.labelColor.withAlphaComponent(0.18))).setStroke()
        path.lineWidth = 1
        path.stroke()
        let text = recording ? "Type a shortcut…" : (spec.isEmpty ? "Click to record" : HotKey.display(spec))
        let p = NSMutableParagraphStyle()
        p.alignment = .center
        let font = recording || spec.isEmpty ? NSFont.systemFont(ofSize: 12) : NSFont.systemFont(ofSize: 13, weight: .medium)
        let color: NSColor = !isEnabled ? .tertiaryLabelColor : (recording || spec.isEmpty ? .secondaryLabelColor : .labelColor)
        let h = font.ascender - font.descender
        (text as NSString).draw(in: NSRect(x: 4, y: (bounds.height - h) / 2 - 1, width: bounds.width - 8, height: h + 2), withAttributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: p,
        ])
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        if recording { stop(); return }
        window?.makeFirstResponder(self)
        recording = true
        rejected = false
        NotificationCenter.default.post(name: .terminalRecordingShortcut, object: true)
    }

    private func stop() {
        guard recording else { return }
        recording = false
        NotificationCenter.default.post(name: .terminalRecordingShortcut, object: false)
    }

    override func resignFirstResponder() -> Bool {
        stop()
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        record(event)
    }

    /// ⌘ shortcuts arrive here before the menus see them.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard recording, window?.firstResponder === self else { return false }
        record(event)
        return true
    }

    private func record(_ event: NSEvent) {
        if event.keyCode == 53 { stop(); return }   // Esc
        guard let new = HotKey.spec(for: event), HotKey.parse(new) != nil else {
            rejected = true
            NSSound.beep()
            return
        }
        spec = new
        stop()
        onChange?(new)
    }
}

// MARK: - Hotkey window position

/// A little screen showing where the hotkey window drops in. Animates when
/// the position changes.
final class ScreenPositionPreview: NSView {
    var position = AppConfig.Edge.top { didSet { updateWindowFrame(animated: true) } }
    private let screen = CALayer()
    private let menuBar = CALayer()
    private let panel = CALayer()

    override var intrinsicContentSize: NSSize { NSSize(width: 168, height: 108) }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        screen.cornerRadius = 8
        screen.borderWidth = 1
        screen.masksToBounds = true
        layer?.addSublayer(screen)
        screen.addSublayer(menuBar)
        screen.addSublayer(panel)
        panel.cornerRadius = 4
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        screen.frame = bounds.insetBy(dx: 1, dy: 1)
        menuBar.frame = NSRect(x: 0, y: screen.bounds.height - 7, width: screen.bounds.width, height: 7)
        updateWindowFrame(animated: false)
        CATransaction.commit()
        updateColors()
    }

    override func viewDidChangeEffectiveAppearance() { updateColors() }

    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            screen.backgroundColor = NSColor.labelColor.withAlphaComponent(0.06).cgColor
            screen.borderColor = NSColor.labelColor.withAlphaComponent(0.2).cgColor
            menuBar.backgroundColor = NSColor.labelColor.withAlphaComponent(0.12).cgColor
            panel.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.85).cgColor
        }
    }

    /// Layer coordinates: origin at the bottom left.
    private func updateWindowFrame(animated: Bool) {
        let s = screen.bounds
        let top = s.height - 7
        let r: NSRect
        switch position {
        case .top: r = NSRect(x: 0, y: top - top * 0.45, width: s.width, height: top * 0.45)
        case .bottom: r = NSRect(x: 0, y: 0, width: s.width, height: top * 0.45)
        case .left: r = NSRect(x: 0, y: 0, width: s.width * 0.4, height: top)
        case .right: r = NSRect(x: s.width * 0.6, y: 0, width: s.width * 0.4, height: top)
        case .center: r = NSRect(x: s.width * 0.15, y: top * 0.2, width: s.width * 0.7, height: top * 0.6)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        CATransaction.setAnimationDuration(0.3)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        panel.frame = r.insetBy(dx: 3, dy: 3)
        CATransaction.commit()
    }
}

/// The positions the hotkey window can take, in the order the pickers show them.
enum HotkeyPositions {
    static let all: [AppConfig.Edge] = [.top, .bottom, .left, .right, .center]

    static func makeControl(target: AnyObject, action: Selector) -> NSSegmentedControl {
        let c = NSSegmentedControl(labels: all.map { $0.rawValue.capitalized }, trackingMode: .selectOne, target: target, action: action)
        c.segmentStyle = .rounded
        return c
    }
}

// MARK: - Shell cards

/// One card per installed shell: its name, its path, and a note on the login
/// shell and on zsh (the only one with smart input for now).
final class ShellPickerView: NSView {
    var selected = "" { didSet { needsDisplay = true } }
    var onPick: ((String) -> Void)?
    let shells: [String]
    private var hovered: Int?
    private var trackingArea: NSTrackingArea?
    static let columns = 4
    static let cardHeight: CGFloat = 58
    static let spacing: CGFloat = 10

    init(shells: [String]) {
        self.shells = shells
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    var rows: Int { (shells.count + Self.columns - 1) / Self.columns }
    var preferredHeight: CGFloat { CGFloat(rows) * (Self.cardHeight + Self.spacing) - Self.spacing + 4 }

    private func cardRect(_ i: Int) -> NSRect {
        let n = CGFloat(Self.columns)
        let w = (bounds.width - Self.spacing * (n - 1)) / n
        return NSRect(x: CGFloat(i % Self.columns) * (w + Self.spacing), y: 2 + CGFloat(i / Self.columns) * (Self.cardHeight + Self.spacing),
                      width: w, height: Self.cardHeight)
    }

    override func draw(_ dirtyRect: NSRect) {
        let login = Shells.login
        for (i, path) in shells.enumerated() {
            let r = cardRect(i)
            let isSelected = path == selected
            let p = NSBezierPath(roundedRect: r, xRadius: 10, yRadius: 10)
            (isSelected ? NSColor.controlAccentColor.withAlphaComponent(0.18) : NSColor.labelColor.withAlphaComponent(hovered == i ? 0.09 : 0.05)).setFill()
            p.fill()
            p.lineWidth = isSelected ? 2 : 1
            (isSelected ? NSColor.controlAccentColor : NSColor.labelColor.withAlphaComponent(0.1)).setStroke()
            p.stroke()
            (Shells.name(path) as NSString).draw(at: NSPoint(x: r.minX + 12, y: r.minY + 10), withAttributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor.labelColor,
            ])
            var tags: [String] = []
            if path == login { tags.append("login shell") }
            if Shells.hasIntegration(path) { tags.append("smart input") }
            let detail = tags.isEmpty ? (path as NSString).deletingLastPathComponent : tags.joined(separator: " · ")
            let style = NSMutableParagraphStyle()
            style.lineBreakMode = .byTruncatingMiddle
            (detail as NSString).draw(in: NSRect(x: r.minX + 12, y: r.minY + 32, width: r.width - 24, height: 16), withAttributes: [
                .font: NSFont.systemFont(ofSize: 11), .foregroundColor: tags.isEmpty ? NSColor.tertiaryLabelColor : NSColor.secondaryLabelColor,
                .paragraphStyle: style,
            ])
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(t)
        trackingArea = t
        removeAllToolTips()
        for (i, path) in shells.enumerated() { addToolTip(cardRect(i), owner: path as NSString, userData: nil) }
    }

    private func index(at event: NSEvent) -> Int? {
        let p = convert(event.locationInWindow, from: nil)
        return shells.indices.first { cardRect($0).contains(p) }
    }

    override func mouseMoved(with event: NSEvent) {
        let h = index(at: event)
        if h != hovered { hovered = h; needsDisplay = true }
    }

    override func mouseExited(with event: NSEvent) { hovered = nil; needsDisplay = true }

    override func mouseDown(with event: NSEvent) {
        guard let i = index(at: event) else { return }
        selected = shells[i]
        onPick?(shells[i])
    }
}
