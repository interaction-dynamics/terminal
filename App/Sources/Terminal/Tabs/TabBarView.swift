import AppKit

/// Warp-style tab bar drawn in the title bar: rounded tabs, folder or command as label, a `+` button.
final class TabBarView: NSView {
    struct Item {
        var label: String
        var detail = ""
        var active: Bool
        var bell: Bool
        /// SF Symbol drawn before the label (the Settings tab).
        var symbol: String?
    }

    var items: [Item] = [] { didSet { needsDisplay = true; updateTracking() } }
    var leadingInset: CGFloat = Theme.trafficLightsInset { didSet { needsDisplay = true } }
    var onSelect: ((Int) -> Void)?
    var onClose: ((Int) -> Void)?
    var onNew: (() -> Void)?

    private var hovered: Int?
    private var hoveredClose = false
    private var hoveredPlus = false
    private var trackingArea: NSTrackingArea?

    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    private var tabWidth: CGFloat {
        let available = bounds.width - leadingInset - 48
        guard !items.isEmpty else { return 0 }
        return max(80, min(200, available / CGFloat(items.count) - 6))
    }

    private func tabRect(_ i: Int) -> NSRect {
        let y = (bounds.height - Theme.tabHeight) / 2
        return NSRect(x: leadingInset + CGFloat(i) * (tabWidth + 6), y: y, width: tabWidth, height: Theme.tabHeight)
    }

    private var plusRect: NSRect {
        let x = items.isEmpty ? leadingInset : tabRect(items.count - 1).maxX + 6
        return NSRect(x: x, y: (bounds.height - Theme.tabHeight) / 2, width: Theme.tabHeight, height: Theme.tabHeight)
    }

    private func closeRect(_ i: Int) -> NSRect {
        let r = tabRect(i)
        return NSRect(x: r.maxX - 22, y: r.midY - 8, width: 16, height: 16)
    }

    override func draw(_ dirtyRect: NSRect) {
        let theme = Theme.current
        // Hairline under the bar.
        theme.separator.setFill()
        NSRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1).fill()

        do {
            for (i, item) in items.enumerated() {
                let r = tabRect(i)
                if item.active {
                    theme.tabActive.setFill()
                    NSBezierPath(roundedRect: r, xRadius: Theme.tabCorner, yRadius: Theme.tabCorner).fill()
                } else if hovered == i {
                    theme.tabHover.setFill()
                    NSBezierPath(roundedRect: r, xRadius: Theme.tabCorner, yRadius: Theme.tabCorner).fill()
                }
                let color = item.active ? theme.foreground : theme.dim
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 12, weight: item.active ? .medium : .regular),
                    .foregroundColor: color,
                    .paragraphStyle: {
                        let p = NSMutableParagraphStyle()
                        p.alignment = .center
                        p.lineBreakMode = .byTruncatingMiddle
                        return p
                    }(),
                ]
                let label = (item.bell ? "• " : "") + item.label
                let textRect = r.insetBy(dx: 24, dy: 0).offsetBy(dx: 0, dy: (r.height - 16) / 2 - 1)
                (label as NSString).draw(in: NSRect(x: textRect.minX, y: r.minY + (r.height - 16) / 2, width: textRect.width, height: 16), withAttributes: attrs)

                if hovered == i {
                    let cr = closeRect(i)
                    if hoveredClose {
                        theme.tabActive.setFill()
                        NSBezierPath(roundedRect: cr, xRadius: 4, yRadius: 4).fill()
                    }
                    drawX(in: cr.insetBy(dx: 4.5, dy: 4.5), color: theme.dim)
                }
            }
        }

        let pr = plusRect
        if hoveredPlus {
            theme.tabHover.setFill()
            NSBezierPath(roundedRect: pr, xRadius: Theme.tabCorner, yRadius: Theme.tabCorner).fill()
        }
        drawPlus(in: pr.insetBy(dx: 8, dy: 8), color: hoveredPlus ? theme.foreground : theme.dim)
    }

    private func drawX(in r: NSRect, color: NSColor) {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: r.minX, y: r.minY)); p.line(to: NSPoint(x: r.maxX, y: r.maxY))
        p.move(to: NSPoint(x: r.maxX, y: r.minY)); p.line(to: NSPoint(x: r.minX, y: r.maxY))
        p.lineWidth = 1.3
        p.lineCapStyle = .round
        color.setStroke()
        p.stroke()
    }

    private func drawPlus(in r: NSRect, color: NSColor) {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: r.midX, y: r.minY)); p.line(to: NSPoint(x: r.midX, y: r.maxY))
        p.move(to: NSPoint(x: r.minX, y: r.midY)); p.line(to: NSPoint(x: r.maxX, y: r.midY))
        p.lineWidth = 1.4
        p.lineCapStyle = .round
        color.setStroke()
        p.stroke()
    }

    // MARK: Mouse

    private func updateTracking() {
        if let trackingArea { removeTrackingArea(trackingArea) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(t)
        trackingArea = t
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        updateTracking()
    }

    private func index(at p: NSPoint) -> Int? {
        return items.indices.first { tabRect($0).contains(p) }
    }

    override func mouseMoved(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let h = index(at: p)
        let hc = h.map { closeRect($0).contains(p) } ?? false
        let hp = plusRect.contains(p)
        if h != hovered || hc != hoveredClose || hp != hoveredPlus {
            hovered = h; hoveredClose = hc; hoveredPlus = hp
            needsDisplay = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        hovered = nil; hoveredClose = false; hoveredPlus = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if plusRect.contains(p) { onNew?(); return }
        if let i = index(at: p) {
            if closeRect(i).contains(p) { onClose?(i) } else { onSelect?(i) }
            return
        }
        // Empty space: drag the window, double-click zooms like a title bar.
        if event.clickCount == 2 { window?.performZoom(nil) } else { window?.performDrag(with: event) }
    }

    override func otherMouseDown(with event: NSEvent) {
        // Middle-click closes a tab.
        if let i = index(at: convert(event.locationInWindow, from: nil)) { onClose?(i) }
    }
}
