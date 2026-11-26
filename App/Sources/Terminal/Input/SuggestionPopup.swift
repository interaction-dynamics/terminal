import AppKit

/// The list shown above the input box: Tab completions, or Ctrl+R history search.
/// Keys stay in the input box, which forwards ↑/↓/Tab/Enter/Esc here.
final class SuggestionPopup {
    struct Row { var title: String; var detail: String? }

    private let panel: NSPanel
    private let list = SuggestionListView()
    private(set) var isVisible = false
    var rows: [Row] { list.rows }
    var selectedIndex: Int { list.selected }
    var onPick: ((Int) -> Void)?

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 200), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView = list
        list.onClick = { [weak self] i in self?.onPick?(i) }
    }

    /// Shows rows above `anchor` (a rect in screen coordinates: the input caret line).
    func show(rows: [Row], above anchor: NSRect, in parent: NSWindow, header: String?) {
        guard !rows.isEmpty else { hide(); return }
        list.rows = rows
        list.header = header
        list.selected = 0
        let visible = min(rows.count, 10)
        let height = CGFloat(visible) * SuggestionListView.rowHeight + 10 + (header == nil ? 0 : SuggestionListView.headerHeight)
        let width = min(max(list.idealWidth, 260), 640)
        var frame = NSRect(x: anchor.minX - 8, y: anchor.maxY + 6, width: width, height: height)
        if let screen = parent.screen?.visibleFrame, frame.maxY > screen.maxY {
            frame.origin.y = anchor.minY - height - 6   // no room above: open below
        }
        panel.setFrame(frame, display: true)
        if !isVisible {
            parent.addChildWindow(panel, ordered: .above)
            isVisible = true
        }
        list.needsDisplay = true
    }

    func hide() {
        guard isVisible else { return }
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
        isVisible = false
    }

    func move(_ delta: Int) {
        guard !list.rows.isEmpty else { return }
        list.selected = (list.selected + delta + list.rows.count) % list.rows.count
        list.scrollToSelection()
        list.needsDisplay = true
    }
}

final class SuggestionListView: NSView {
    static let rowHeight: CGFloat = 24
    static let headerHeight: CGFloat = 22
    var rows: [SuggestionPopup.Row] = []
    var header: String?
    var selected = 0
    var onClick: ((Int) -> Void)?
    private var firstVisible = 0

    override var isFlipped: Bool { true }

    var idealWidth: CGFloat {
        let font = Theme.current.font.withSize(13)
        let widest = rows.prefix(50).map { row -> CGFloat in
            let t = (row.title as NSString).size(withAttributes: [.font: font]).width
            let d = row.detail.map { ($0 as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 11)]).width + 24 } ?? 0
            return t + d
        }.max() ?? 0
        return widest + 40
    }

    func scrollToSelection() {
        let visible = 10
        if selected < firstVisible { firstVisible = selected }
        if selected >= firstVisible + visible { firstVisible = selected - visible + 1 }
    }

    override func draw(_ dirtyRect: NSRect) {
        let theme = Theme.current
        let bg = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: Theme.menuCorner, yRadius: Theme.menuCorner)
        theme.background.blended(withFraction: theme.background.brightness < 0.5 ? 0.06 : 0.0, of: .white)?.setFill()
        bg.fill()
        theme.separator.setStroke()
        bg.lineWidth = 1
        bg.stroke()

        var y: CGFloat = 5
        if let header {
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: theme.dim]
            (header as NSString).draw(at: NSPoint(x: 14, y: y + 4), withAttributes: attrs)
            y += Self.headerHeight
        }
        let font = theme.font.withSize(13)
        let end = min(rows.count, firstVisible + 10)
        for i in firstVisible..<end {
            let r = NSRect(x: 5, y: y, width: bounds.width - 10, height: Self.rowHeight)
            if i == selected {
                theme.accent.withAlphaComponent(0.22).setFill()
                NSBezierPath(roundedRect: r, xRadius: 6, yRadius: 6).fill()
            }
            let row = rows[i]
            var detailWidth: CGFloat = 0
            if let detail = row.detail {
                let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: theme.dim]
                let w = (detail as NSString).size(withAttributes: attrs).width
                detailWidth = w + 16
                (detail as NSString).draw(at: NSPoint(x: r.maxX - w - 10, y: r.minY + 5), withAttributes: attrs)
            }
            let p = NSMutableParagraphStyle()
            p.lineBreakMode = .byTruncatingMiddle
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: theme.foreground, .paragraphStyle: p]
            (row.title as NSString).draw(in: NSRect(x: r.minX + 9, y: r.minY + 4, width: r.width - 18 - detailWidth, height: 18), withAttributes: attrs)
            y += Self.rowHeight
        }
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let top: CGFloat = 5 + (header == nil ? 0 : Self.headerHeight)
        let i = firstVisible + Int((p.y - top) / Self.rowHeight)
        if i >= 0 && i < rows.count { onClick?(i) }
    }

    override func scrollWheel(with event: NSEvent) {
        let step = event.scrollingDeltaY > 0 ? -1 : (event.scrollingDeltaY < 0 ? 1 : 0)
        firstVisible = max(0, min(max(rows.count - 10, 0), firstVisible + step))
        needsDisplay = true
    }
}
