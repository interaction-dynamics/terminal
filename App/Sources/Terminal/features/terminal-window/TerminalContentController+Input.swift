import AppKit

extension TerminalContentController {
    // MARK: SmartTextViewDelegate

    func smartTextSubmit(_ view: SmartTextView) {
        guard let s = active else { return }
        let command = view.string
        view.ghost = ""
        hidePopup()
        historyCursor = nil
        view.text = ""
        view.undoManager?.removeAllActions()
        s.submit(command)
        refresh()
        window(makeFirstResponder: s.surface.view)
    }

    private func window(makeFirstResponder view: NSView) {
        root.window?.makeFirstResponder(view)
    }

    func smartTextHistory(_ view: SmartTextView, older: Bool) -> Bool {
        let recent = HistoryStore.shared.recentSnapshot
        guard !recent.isEmpty else { return false }
        if historyCursor == nil {
            guard older else { return false }
            historyDraft = view.string
        }
        let current = historyCursor ?? recent.count
        // Only walk through commands starting with what was typed (like zsh's up-line-or-search).
        let prefix = historyDraft
        var i = current
        repeat {
            i += older ? -1 : 1
        } while i >= 0 && i < recent.count && !prefix.isEmpty && !recent[i].hasPrefix(prefix)
        if i < 0 { return true }
        if i >= recent.count {
            historyCursor = nil
            view.text = historyDraft
            return true
        }
        historyCursor = i
        view.text = recent[i]
        view.ghost = ""
        return true
    }

    func smartTextTab(_ view: SmartTextView) {
        guard let s = active else { return }
        let line = view.string
        let cursorOffset = view.selectedRange().location
        let cursor = String.Index(utf16Offset: cursorOffset, in: line)
        Completer.shared.complete(line: line, cursor: cursor, cwd: s.cwd) { [weak self] items in
            guard let self, view.string == line else { return }
            let ctx = WordContext.parse(line, cursor: cursor)
            self.completions = items
            self.completionRange = ctx.range
            if items.count == 1 {
                self.apply(items[0])
            } else if !items.isEmpty {
                // Fill the common prefix first, like a shell.
                let common = Self.commonPrefix(items.map(\.replacement))
                let currentWord = String(line[ctx.range])
                if common.count > currentWord.count, !common.hasSuffix(" ") {
                    self.apply(Completion(replacement: common, display: common, kind: .file))
                    self.completionRange = WordContext.parse(view.string, cursor: view.string.index(view.string.startIndex, offsetBy: (String(line[..<ctx.range.lowerBound]) + common).count)).range
                }
                self.popupMode = .completion
                self.popup.show(rows: items.map { SuggestionPopup.Row(title: $0.display, detail: Self.kindLabel($0.kind)) },
                                above: view.caretScreenRect, in: view.window!, header: nil)
            } else {
                NSSound.beep()
            }
        }
    }

    private static func kindLabel(_ k: Completion.Kind) -> String {
        switch k {
        case .folder: return "folder"
        case .file: return "file"
        case .command: return "command"
        case .branch: return "branch"
        case .script: return "script"
        case .subcommand: return "subcommand"
        case .history: return "history"
        }
    }

    static func commonPrefix(_ strings: [String]) -> String {
        guard var prefix = strings.first else { return "" }
        for s in strings.dropFirst() {
            while !s.hasPrefix(prefix) { prefix.removeLast() }
        }
        return prefix
    }

    private func apply(_ c: Completion) {
        let tv = input.textView
        let line = tv.string
        guard let range = completionRange, range.upperBound <= line.endIndex else { return }
        let ns = NSRange(range, in: line)
        tv.insertText(c.replacement, replacementRange: ns)
        hidePopup()
    }

    func smartTextHistorySearch(_ view: SmartTextView) {
        popupMode = .history
        updateHistorySearch()
    }

    private func updateHistorySearch() {
        guard let s = active else { return }
        let query = input.textView.string
        let ctx = s.rankContext
        let gen = suggestGeneration
        HistoryStore.shared.queue.async { [weak self] in
            let matches = Ranker.fuzzyMatches(query, in: HistoryStore.shared.index.stats, ctx: ctx)
            DispatchQueue.main.async {
                guard let self, self.popupMode == .history, gen == self.suggestGeneration, let window = self.input.window else { return }
                self.historyMatches = matches
                if matches.isEmpty { self.popup.hide(); return }
                self.popup.show(rows: matches.map { SuggestionPopup.Row(title: $0, detail: nil) },
                                above: self.input.textView.caretScreenRect, in: window,
                                header: "History  ·  ⏎ pick  ·  ⌘⌫ delete")
            }
        }
    }

    func smartTextInterrupt(_ view: SmartTextView) {
        hidePopup()
        historyCursor = nil
        view.text = ""
        view.ghost = ""
    }

    func smartTextEOF(_ view: SmartTextView) {
        active?.sendEOF()
    }

    func smartTextClearScreen(_ view: SmartTextView) {
        active?.surface.sendKey(.clearScreen)
    }

    func smartTextEscape(_ view: SmartTextView) -> Bool {
        if popup.isVisible { hidePopup(); return true }
        return false
    }

    func smartTextPopupKey(_ view: SmartTextView, _ key: SmartTextView.PopupKey) -> Bool {
        guard popup.isVisible else { return false }
        switch key {
        case .up: popup.move(-1)
        case .down, .tab: popup.move(1)
        case .accept: pickPopup(popup.selectedIndex)
        }
        return true
    }

    func pickPopup(_ i: Int) {
        switch popupMode {
        case .completion where completions.indices.contains(i):
            apply(completions[i])
        case .history where historyMatches.indices.contains(i):
            input.textView.text = historyMatches[i]
            hidePopup()
        default:
            hidePopup()
        }
        root.window?.makeFirstResponder(input.textView)
    }

    /// ⌘⌫ in the history popup deletes the selected command from history.
    func smartTextDeleteHistoryEntry(_ view: SmartTextView) -> Bool {
        guard popupMode == .history, popup.isVisible, historyMatches.indices.contains(popup.selectedIndex) else { return false }
        HistoryStore.shared.delete(command: historyMatches[popup.selectedIndex])
        updateHistorySearch()
        return true
    }

    func hidePopup() {
        popup.hide()
        popupMode = .none
    }

    func smartTextDidChange(_ view: SmartTextView) {
        suggestGeneration += 1
        root.needsLayout = true
        Completer.shared.warmUp()
        if popupMode == .completion { hidePopup() }
        if popupMode == .history { updateHistorySearch() }
        updateGhost()
    }

    /// Ghost suggestion off the main thread; a newer keystroke cancels older results.
    private func updateGhost() {
        let tv = input.textView
        let text = tv.string
        guard let s = active, tv.caretAtEnd, !text.isEmpty, !text.contains("\n") else { tv.ghost = ""; return }
        let ctx = s.rankContext
        let gen = suggestGeneration
        HistoryStore.shared.bestMatch(text, ctx: ctx) { [weak self] best in
            guard let self, gen == self.suggestGeneration, tv.string == text else { return }
            tv.ghost = best.map { String(decoding: $0.utf8.dropFirst(text.utf8.count), as: UTF8.self) } ?? ""
        }
    }
}
