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
