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
