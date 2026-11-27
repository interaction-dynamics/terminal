import AppKit

/// Vertical tab list (specs/02-look.md), left or right of the terminal:
/// a "New tab" row, then one card per tab with its title, its folder in dim
/// text and its ⌘N shortcut (a close button on hover).
final class TabSidebarView: NSView {
    var items: [TabBarView.Item] = [] { didSet { needsDisplay = true } }
    var edge: AppConfig.TabsPosition = .left { didSet { needsDisplay = true } }
    var onSelect: ((Int) -> Void)?
    var onClose: ((Int) -> Void)?
    var onNew: (() -> Void)?

    private var hovered: Int?
    private var hoveredClose = false
    private var hoveredNew = false
    private var trackingArea: NSTrackingArea?

    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    private var newRect: NSRect {
        NSRect(x: Theme.sidebarMargin, y: Theme.sidebarMargin, width: bounds.width - 2 * Theme.sidebarMargin, height: Theme.sidebarRowHeight)
    }

    private func cardRect(_ i: Int) -> NSRect {
        let top = newRect.maxY + 6
        return NSRect(x: Theme.sidebarMargin, y: top + CGFloat(i) * (Theme.sidebarCardHeight + 2),
                      width: bounds.width - 2 * Theme.sidebarMargin, height: Theme.sidebarCardHeight)
    }

    private func closeRect(_ i: Int) -> NSRect {
        let r = cardRect(i)
        return NSRect(x: r.maxX - 24, y: r.midY - 9, width: 18, height: 18)
    }

    override func draw(_ dirtyRect: NSRect) {
        let theme = Theme.current
        // A shade apart from the terminal, with a hairline on the inner edge.
        theme.chromeBackground.setFill()
        bounds.fill()
        theme.foreground.withAlphaComponent(0.025).setFill()
        bounds.fill(using: .sourceOver)
        theme.separator.setFill()
        let lineX = edge == .left ? bounds.width - 1 : 0
        NSRect(x: lineX, y: 0, width: 1, height: bounds.height).fill(using: .sourceOver)

        // "New tab" row.
        let nr = newRect
        if hoveredNew {
            theme.tabHover.setFill()
            NSBezierPath(roundedRect: nr, xRadius: Theme.tabCorner, yRadius: Theme.tabCorner).fill()
        }
        let newColor = hoveredNew ? theme.foreground : theme.dim
        drawPlus(in: NSRect(x: nr.minX + 10, y: nr.midY - 5, width: 10, height: 10), color: newColor)
        ("New tab" as NSString).draw(at: NSPoint(x: nr.minX + 28, y: nr.midY - 8), withAttributes: [
            .font: NSFont.systemFont(ofSize: 12), .foregroundColor: newColor,
        ])
        drawShortcut("⌘T", right: nr.maxX - 10, midY: nr.midY, color: theme.dim)

        for (i, item) in items.enumerated() {
            let r = cardRect(i)
            guard r.intersects(dirtyRect) else { continue }
            let path = NSBezierPath(roundedRect: r, xRadius: Theme.tabCorner, yRadius: Theme.tabCorner)
            if item.active {
                theme.tabActive.setFill()
                path.fill()
                theme.foreground.withAlphaComponent(0.08).setStroke()
                path.lineWidth = 1
                path.stroke()
            } else if hovered == i {
                theme.tabHover.setFill()
                path.fill()
            }

            var x = r.minX + 10
            if item.bell {
                theme.accent.setFill()
                NSBezierPath(ovalIn: NSRect(x: x, y: r.minY + 13, width: 6, height: 6)).fill()
                x += 11
            }
            let right = r.maxX - 34
            let truncating: NSParagraphStyle = {
                let p = NSMutableParagraphStyle()
                p.lineBreakMode = .byTruncatingMiddle
                return p
            }()
            (item.label as NSString).draw(in: NSRect(x: x, y: r.minY + 7, width: right - x, height: 16), withAttributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: item.active ? .medium : .regular),
                .foregroundColor: item.active ? theme.foreground : theme.foreground.withAlphaComponent(0.8),
                .paragraphStyle: truncating,
            ])
            if !item.detail.isEmpty {
                let head: NSParagraphStyle = {
                    let p = NSMutableParagraphStyle()
                    p.lineBreakMode = .byTruncatingHead
                    return p
                }()
                (item.detail as NSString).draw(in: NSRect(x: r.minX + 10, y: r.minY + 24, width: right - r.minX - 10, height: 14), withAttributes: [
                    .font: NSFont.systemFont(ofSize: 10.5), .foregroundColor: theme.dim, .paragraphStyle: head,
                ])
            }

            if hovered == i {
                let cr = closeRect(i)
                if hoveredClose {
                    theme.tabActive.setFill()
                    NSBezierPath(roundedRect: cr, xRadius: 4, yRadius: 4).fill()
                }
                drawX(in: cr.insetBy(dx: 5, dy: 5), color: hoveredClose ? theme.foreground : theme.dim)
            } else if i < 9 {
                drawShortcut(i == 8 ? "⌘9" : "⌘\(i + 1)", right: r.maxX - 10, midY: r.midY, color: theme.dim)
            }
        }
    }

    private func drawShortcut(_ text: String, right: CGFloat, midY: CGFloat, color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10.5), .foregroundColor: color.withAlphaComponent(0.7),
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        (text as NSString).draw(at: NSPoint(x: right - size.width, y: midY - size.height / 2), withAttributes: attrs)
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

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(t)
        trackingArea = t
    }

    private func index(at p: NSPoint) -> Int? { items.indices.first { cardRect($0).contains(p) } }

    override func mouseMoved(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let h = index(at: p)
        let hc = h.map { closeRect($0).contains(p) } ?? false
        let hn = newRect.contains(p)
        if h != hovered || hc != hoveredClose || hn != hoveredNew {
            hovered = h; hoveredClose = hc; hoveredNew = hn
            needsDisplay = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        hovered = nil; hoveredClose = false; hoveredNew = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if newRect.contains(p) { onNew?(); return }
        guard let i = index(at: p) else { return }
        if closeRect(i).contains(p), hovered == i { onClose?(i) } else { onSelect?(i) }
    }

    override func otherMouseDown(with event: NSEvent) {
        // Middle-click closes a tab.
        if let i = index(at: convert(event.locationInWindow, from: nil)) { onClose?(i) }
    }
}

/// The strip across the top of the window: traffic lights on the left, the
/// settings gear on the right, the active tab's title in between when the
/// tabs are in a sidebar. Drags the window; double-click zooms.
final class TitleBarView: NSView {
    var title = "" { didSet { if title != oldValue { needsDisplay = true } } }
    var showsTitle = false { didSet { needsDisplay = true } }

    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let theme = Theme.current
        theme.separator.setFill()
        NSRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1).fill(using: .sourceOver)
        guard showsTitle, !title.isEmpty else { return }
        let p = NSMutableParagraphStyle()
        p.alignment = .center
        p.lineBreakMode = .byTruncatingMiddle
        let inset = Theme.trafficLightsInset + 8
        (title as NSString).draw(in: NSRect(x: inset, y: (bounds.height - 16) / 2, width: bounds.width - 2 * inset, height: 16), withAttributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium), .foregroundColor: theme.dim, .paragraphStyle: p,
        ])
    }

    override func mouseDown(with event: NSEvent) {
        // The borderless hotkey dropdown stays where it is.
        guard let window, window.styleMask.contains(.titled) else { return }
        if event.clickCount == 2 { window.performZoom(nil) } else { window.performDrag(with: event) }
    }
}
