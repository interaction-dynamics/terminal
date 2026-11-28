import AppKit

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
