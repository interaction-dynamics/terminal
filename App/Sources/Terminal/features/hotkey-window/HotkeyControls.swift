import AppKit

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
