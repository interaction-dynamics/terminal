import AppKit

/// Bottom-pinned input area (Warp layout): our prompt line, then the smart input box.
final class InputAreaView: NSView {
    let promptLine = PromptLineView()
    let textView = SmartTextView()
    private let scroll = NSScrollView()
    static let maxLines = 10

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layerContentsRedrawPolicy = .duringViewResize
        scroll.documentView = textView
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = false
        scroll.borderType = .noBorder
        scroll.verticalScrollElasticity = .none
        addSubview(promptLine)
        addSubview(scroll)
    }

    required init?(coder: NSCoder) { fatalError() }

    var lineHeight: CGFloat {
        let f = Theme.current.font
        return ceil(f.ascender - f.descender + f.leading)
    }

    /// Height for the current text: prompt line + 1…maxLines lines + padding.
    var preferredHeight: CGFloat {
        let lines = max(1, min(Self.maxLines, textView.string.components(separatedBy: "\n").count + wrappedExtraLines))
        return Theme.paddingY + PromptLineView.height + 6 + CGFloat(lines) * lineHeight + Theme.paddingY
    }

    private var wrappedExtraLines: Int {
        guard let lm = textView.layoutManager, let tc = textView.textContainer else { return 0 }
        lm.ensureLayout(for: tc)
        let used = lm.usedRect(for: tc).height
        let explicit = textView.string.components(separatedBy: "\n").count
        return max(0, Int(round(used / lineHeight)) - explicit)
    }

    override func layout() {
        super.layout()
        let w = bounds.width - Theme.paddingX * 2
        promptLine.frame = NSRect(x: Theme.paddingX, y: Theme.paddingY, width: w, height: PromptLineView.height)
        let top = promptLine.frame.maxY + 6
        scroll.frame = NSRect(x: Theme.paddingX, y: top, width: w, height: bounds.height - top - Theme.paddingY)
        textView.frame.size.width = w
        textView.minSize = NSSize(width: w, height: lineHeight)
        textView.maxSize = NSSize(width: w, height: .greatestFiniteMagnitude)
    }

    override func draw(_ dirtyRect: NSRect) {
        // Same colour as the terminal behind the output, so both read as one surface.
        let theme = Theme.current
        theme.chromeBackground.setFill()
        bounds.fill()
        theme.separator.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 1).fill(using: .sourceOver)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(textView)
    }

    func applyTheme() {
        textView.applyTheme()
        promptLine.needsDisplay = true
        needsLayout = true
        needsDisplay = true
    }
}

/// Folder and git branch as Warp-style chips (icon + text in a rounded
/// outline), then the last exit status and duration, drawn above the input box.
final class PromptLineView: NSView {
    /// Look of the chips. Tune here.
    enum Chip {
        static let paddingX: CGFloat = 7
        static let iconGap: CGFloat = 5
        static let spacing: CGFloat = 6
        static let radius: CGFloat = 5
        static let verticalInset: CGFloat = 2
        /// The folder chip never shrinks below this before the branch chip goes.
        static let minFolderWidth: CGFloat = 90
    }

    static var fontSize: CGFloat { max(9, CGFloat(ConfigStore.shared.fontSize) - 2) }
    static var height: CGFloat { ceil(fontSize * 1.5) + Chip.verticalInset * 2 + 4 }

    var directory = "~" { didSet { needsDisplay = true } }
    var branch: String? { didSet { needsDisplay = true } }
    var exitCode: Int? { didSet { needsDisplay = true } }
    var durationMs: Int? { didSet { needsDisplay = true } }
    var hint: String? { didSet { needsDisplay = true } }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let theme = Theme.current
        let font = NSFont.monospacedSystemFont(ofSize: Self.fontSize, weight: .regular)
        let text = theme.foreground.withAlphaComponent(0.72)
        let chipH = bounds.height - Chip.verticalInset * 2

        // Right side first: status, duration and hint keep their room; the
        // chips take what is left (the folder is truncated from the start).
        var right = bounds.width
        if let hint {
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: theme.dim]
            let w = (hint as NSString).size(withAttributes: attrs).width
            right -= w
            (hint as NSString).draw(at: NSPoint(x: right, y: (bounds.height - 13) / 2), withAttributes: attrs)
            right -= 12
        }

        let status = NSMutableAttributedString()
        if let code = exitCode, code != 0 {
            status.append(NSAttributedString(string: "✗ \(code)", attributes: [.font: font, .foregroundColor: theme.error]))
        }
        if let ms = durationMs, ms >= 100 {
            if status.length > 0 { status.append(NSAttributedString(string: "  ", attributes: [.font: font])) }
            status.append(NSAttributedString(string: Self.format(ms), attributes: [.font: font, .foregroundColor: theme.dim]))
        }

        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: text]
        let iconSize = ceil(Self.fontSize * 0.95)
        let chrome = Chip.paddingX * 2 + iconSize + Chip.iconGap
        func width(_ s: String) -> CGFloat { ceil((s as NSString).size(withAttributes: attrs).width) + chrome }

        let statusW = status.length > 0 ? ceil(status.size().width) + Chip.spacing + 4 : 0
        let room = right - statusW
        var folderW = width(directory)
        var branchW = branch.map(width) ?? 0
        if folderW + (branch == nil ? 0 : Chip.spacing + branchW) > room {
            folderW = max(Chip.minFolderWidth, room - (branch == nil ? 0 : Chip.spacing + branchW))
            if folderW + Chip.spacing + branchW > room { branchW = 0 }   // too narrow: drop the branch
            folderW = min(folderW, room)
        }

        var x: CGFloat = 0
        drawChip(symbol: "folder", text: directory, x: x, width: folderW, height: chipH, iconSize: iconSize, attrs: attrs, tint: nil)
        x += folderW + Chip.spacing
        if let branch, branchW > 0 {
            // The branch (or commit) chip carries the theme's green, like the folder's grey.
            var branchAttrs = attrs
            branchAttrs[.foregroundColor] = theme.success
            drawChip(symbol: "arrow.triangle.branch", text: branch, x: x, width: branchW, height: chipH, iconSize: iconSize, attrs: branchAttrs, tint: theme.success)
            x += branchW + Chip.spacing
        }
        if status.length > 0 {
            let h = status.size().height
            status.draw(at: NSPoint(x: x + 4, y: (bounds.height - h) / 2))
        }
    }

    private func drawChip(symbol: String, text: String, x: CGFloat, width: CGFloat, height: CGFloat,
                          iconSize: CGFloat, attrs: [NSAttributedString.Key: Any], tint: NSColor?) {
        let theme = Theme.current
        let rect = NSRect(x: x, y: Chip.verticalInset, width: width, height: height).insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: Chip.radius, yRadius: Chip.radius)
        (tint ?? theme.foreground).withAlphaComponent(tint == nil ? 0.04 : 0.08).setFill()
        path.fill()
        (tint ?? theme.foreground).withAlphaComponent(tint == nil ? 0.18 : 0.4).setStroke()
        path.lineWidth = 1
        path.stroke()

        let color = (attrs[.foregroundColor] as? NSColor) ?? theme.dim
        if let image = Self.icon(symbol, size: iconSize, color: color) {
            let s = image.size
            image.draw(in: NSRect(x: rect.minX + Chip.paddingX, y: rect.midY - s.height / 2, width: s.width, height: s.height))
        }
        let textX = rect.minX + Chip.paddingX + iconSize + Chip.iconGap
        let font = attrs[.font] as! NSFont
        let lineH = ceil(font.ascender - font.descender)
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingHead
        var a = attrs
        a[.paragraphStyle] = style
        (text as NSString).draw(in: NSRect(x: textX, y: rect.midY - lineH / 2, width: rect.maxX - Chip.paddingX - textX + 1, height: lineH), withAttributes: a)
    }

    /// SF Symbol tinted with the chip's text colour, cached per symbol, size and colour.
    private static var icons: [String: NSImage] = [:]
    private static func icon(_ name: String, size: CGFloat, color: NSColor) -> NSImage? {
        let key = "\(name)|\(size)|\(color)"
        if let cached = icons[key] { return cached }
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config) else { return nil }
        let tinted = NSImage(size: symbol.size, flipped: false) { rect in
            symbol.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        if icons.count > 32 { icons.removeAll() }
        icons[key] = tinted
        return tinted
    }

    static func format(_ ms: Int) -> String {
        if ms < 1000 { return "\(ms)ms" }
        let s = Double(ms) / 1000
        if s < 60 { return String(format: "%.1fs", s) }
        let m = Int(s) / 60
        return "\(m)m \(Int(s) % 60)s"
    }
}
