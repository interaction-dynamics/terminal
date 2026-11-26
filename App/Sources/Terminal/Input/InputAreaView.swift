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

/// Folder, git branch, last exit status and duration, drawn above the input box.
final class PromptLineView: NSView {
    static var height: CGFloat { ceil(max(9, CGFloat(ConfigStore.shared.fontSize) - 1) * 1.5) }
    var directory = "~" { didSet { needsDisplay = true } }
    var branch: String? { didSet { needsDisplay = true } }
    var exitCode: Int? { didSet { needsDisplay = true } }
    var durationMs: Int? { didSet { needsDisplay = true } }
    var hint: String? { didSet { needsDisplay = true } }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let theme = Theme.current
        let size = max(9, CGFloat(ConfigStore.shared.fontSize) - 1)
        let font = NSFont.monospacedSystemFont(ofSize: size, weight: .medium)
        let regular = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        let line = NSMutableAttributedString()
        line.append(NSAttributedString(string: directory, attributes: [.font: font, .foregroundColor: theme.accent]))
        if let branch {
            line.append(NSAttributedString(string: "  " + branch, attributes: [.font: regular, .foregroundColor: theme.success]))
        }
        if let code = exitCode, code != 0 {
            line.append(NSAttributedString(string: "  ✗ \(code)", attributes: [.font: regular, .foregroundColor: theme.error]))
        }
        if let ms = durationMs, ms >= 100 {
            line.append(NSAttributedString(string: "  " + Self.format(ms), attributes: [.font: regular, .foregroundColor: theme.dim]))
        }
        line.draw(at: NSPoint(x: 0, y: 1))

        if let hint {
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: theme.dim]
            let w = (hint as NSString).size(withAttributes: attrs).width
            (hint as NSString).draw(at: NSPoint(x: bounds.width - w, y: 2), withAttributes: attrs)
        }
    }

    static func format(_ ms: Int) -> String {
        if ms < 1000 { return "\(ms)ms" }
        let s = Double(ms) / 1000
        if s < 60 { return String(format: "%.1fs", s) }
        let m = Int(s) / 60
        return "\(m)m \(Int(s) % 60)s"
    }
}
