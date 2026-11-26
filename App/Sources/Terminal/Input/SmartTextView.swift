import AppKit

/// What the input box asks its owner to do. Keeps the text view free of app logic.
protocol SmartTextViewDelegate: AnyObject {
    func smartTextSubmit(_ view: SmartTextView)
    func smartTextHistory(_ view: SmartTextView, older: Bool) -> Bool
    func smartTextTab(_ view: SmartTextView)
    func smartTextHistorySearch(_ view: SmartTextView)
    func smartTextInterrupt(_ view: SmartTextView)
    func smartTextEOF(_ view: SmartTextView)
    func smartTextClearScreen(_ view: SmartTextView)
    func smartTextEscape(_ view: SmartTextView) -> Bool
    /// ↑/↓/Enter/Tab while a popup is open. Returns true if the popup used the key.
    func smartTextPopupKey(_ view: SmartTextView, _ key: SmartTextView.PopupKey) -> Bool
    func smartTextDidChange(_ view: SmartTextView)
    /// ⌘⌫ while the history popup is open. Returns true if an entry was deleted.
    func smartTextDeleteHistoryEntry(_ view: SmartTextView) -> Bool
}

/// The native text box that replaces the shell's line editor at the prompt
/// (specs/04-smart-input.md): full mouse editing, undo, IME, plus shell keys.
final class SmartTextView: NSTextView {
    enum PopupKey { case up, down, accept, tab }

    weak var smartDelegate: SmartTextViewDelegate?
    /// Grey suggestion shown after the text (only when the caret is at the end).
    var ghost: String = "" { didSet { if ghost != oldValue { needsDisplay = true } } }

    var text: String {
        get { string }
        set {
            string = newValue
            setSelectedRange(NSRange(location: (newValue as NSString).length, length: 0))
            didChangeText()
        }
    }

    convenience init() {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: NSSize(width: 1000, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)
        self.init(frame: .zero, textContainer: container)
        isRichText = false
        importsGraphics = false
        allowsUndo = true
        isContinuousSpellCheckingEnabled = false
        isGrammarCheckingEnabled = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isAutomaticDataDetectionEnabled = false
        smartInsertDeleteEnabled = false
        drawsBackground = false
        isVerticallyResizable = true
        isHorizontallyResizable = false
        autoresizingMask = [.width]
        textContainerInset = .zero
        applyTheme()
    }

    func applyTheme() {
        let theme = Theme.current
        font = theme.font
        textColor = theme.foreground
        insertionPointColor = theme.accent
        typingAttributes = [.font: theme.font, .foregroundColor: theme.foreground]
        selectedTextAttributes = [.backgroundColor: theme.accent.withAlphaComponent(0.35)]
        needsDisplay = true
    }

    var caretAtEnd: Bool {
        let r = selectedRange()
        return r.length == 0 && r.location == (string as NSString).length
    }

    private var onFirstLine: Bool {
        let loc = selectedRange().location
        return !(string as NSString).substring(to: loc).contains("\n")
    }

    private var onLastLine: Bool {
        let loc = selectedRange().location + selectedRange().length
        return !(string as NSString).substring(from: loc).contains("\n")
    }

    // MARK: Keys

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let chars = event.charactersIgnoringModifiers ?? ""

        if flags == .control {
            switch chars {
            case "r": smartDelegate?.smartTextHistorySearch(self); return
            case "c": smartDelegate?.smartTextInterrupt(self); return
            case "l": smartDelegate?.smartTextClearScreen(self); return
            case "d" where string.isEmpty: smartDelegate?.smartTextEOF(self); return
            case "u": deleteToLineStart(); return
            case "w": deleteWordBackward(nil); return
            default: break
            }
        }
        if flags == .command, event.keyCode == 51, smartDelegate?.smartTextDeleteHistoryEntry(self) == true { return }
        // Shift+Enter (or Option+Enter) adds a line instead of running.
        if event.keyCode == 36 || event.keyCode == 76 {
            if flags.contains(.shift) || flags.contains(.option) {
                insertText("\n", replacementRange: selectedRange())
                return
            }
        }
        super.keyDown(with: event)
    }

    private func deleteToLineStart() {
        let ns = string as NSString
        let loc = selectedRange().location
        let lineStart = ns.lineRange(for: NSRange(location: loc, length: 0)).location
        guard loc > lineStart else { return }
        let range = NSRange(location: lineStart, length: loc - lineStart)
        if shouldChangeText(in: range, replacementString: "") {
            replaceCharacters(in: range, with: "")
            didChangeText()
        }
    }

    override func doCommand(by selector: Selector) {
        let d = smartDelegate
        switch selector {
        case #selector(insertNewline(_:)):
            if d?.smartTextPopupKey(self, .accept) == true { return }
            d?.smartTextSubmit(self)
        case #selector(insertTab(_:)):
            if d?.smartTextPopupKey(self, .tab) == true { return }
            d?.smartTextTab(self)
        case #selector(moveUp(_:)):
            if d?.smartTextPopupKey(self, .up) == true { return }
            if onFirstLine, d?.smartTextHistory(self, older: true) == true { return }
            super.doCommand(by: selector)
        case #selector(moveDown(_:)):
            if d?.smartTextPopupKey(self, .down) == true { return }
            if onLastLine, d?.smartTextHistory(self, older: false) == true { return }
            super.doCommand(by: selector)
        case #selector(moveRight(_:)), #selector(moveToEndOfLine(_:)), #selector(moveToEndOfParagraph(_:)), #selector(moveToRightEndOfLine(_:)):
            if caretAtEnd, !ghost.isEmpty { acceptGhost(all: true); return }
            super.doCommand(by: selector)
        case #selector(moveWordRight(_:)), #selector(moveWordForward(_:)):
            if caretAtEnd, !ghost.isEmpty { acceptGhost(all: false); return }
            super.doCommand(by: selector)
        case #selector(cancelOperation(_:)):
            if d?.smartTextEscape(self) == true { return }
            if !ghost.isEmpty { ghost = ""; return }
        default:
            super.doCommand(by: selector)
        }
    }

    func acceptGhost(all: Bool) {
        guard !ghost.isEmpty else { return }
        let take: String
        if all {
            take = ghost
        } else {
            // One word: leading spaces plus the next run of non-spaces.
            var s = Substring(ghost)
            var out = ""
            while let c = s.first, c == " " { out.append(c); s = s.dropFirst() }
            while let c = s.first, c != " " { out.append(c); s = s.dropFirst() }
            take = out
        }
        ghost = String(ghost.dropFirst(take.count))
        insertText(take, replacementRange: selectedRange())
    }

    override func didChangeText() {
        super.didChangeText()
        smartDelegate?.smartTextDidChange(self)
    }

    override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelecting)
        needsDisplay = true
    }

    // MARK: Ghost text

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !ghost.isEmpty, caretAtEnd, let layoutManager, let textContainer else { return }
        let ns = string as NSString
        var point: NSPoint
        if ns.length == 0 {
            point = NSPoint(x: textContainerOrigin.x, y: textContainerOrigin.y)
        } else {
            let glyph = layoutManager.glyphIndexForCharacter(at: ns.length - 1)
            var rect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: textContainer)
            if ns.character(at: ns.length - 1) == 10 { // ends with newline: next line start
                rect = NSRect(x: 0, y: rect.maxY, width: 0, height: rect.height)
                point = NSPoint(x: textContainerOrigin.x, y: rect.minY + textContainerOrigin.y)
            } else {
                point = NSPoint(x: rect.maxX + textContainerOrigin.x, y: rect.minY + textContainerOrigin.y)
            }
        }
        let attrs: [NSAttributedString.Key: Any] = [.font: Theme.current.font, .foregroundColor: Theme.current.dim.withAlphaComponent(0.45)]
        let firstLine = ghost.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ghost
        (firstLine as NSString).draw(at: point, withAttributes: attrs)
    }

    /// Screen rect of the caret line, to place popups.
    var caretScreenRect: NSRect {
        let r = firstRect(forCharacterRange: selectedRange(), actualRange: nil)
        return r
    }
}
