// NSView hosting one libghostty surface: keyboard, mouse, IME, sizing, focus.
// Keyboard and IME handling follow Ghostty's macOS SurfaceView
// (MIT licence, see Vendor/ghostty/LICENSE), trimmed to what this app needs.

import AppKit
import GhosttyKit

final class TerminalSurfaceView: NSView, TerminalSurface {
    private(set) var surface: ghostty_surface_t?
    weak var delegate: TerminalSurfaceDelegate?
    var cellSize = CGSize(width: 8, height: 16)
    private var markedText = NSMutableAttributedString()
    private var keyTextAccumulator: [String]?
    private var lastPerformKeyEvent: TimeInterval?
    private var trackingArea: NSTrackingArea?

    var view: NSView { self }
    var scale: CGFloat { window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2 }

    init(options: SurfaceOptions) {
        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        wantsLayer = true
        guard let app = TerminalEngine.shared.app else { return }

        var cfg = ghostty_surface_config_new()
        cfg.userdata = Unmanaged.passUnretained(self).toOpaque()
        cfg.platform_tag = GHOSTTY_PLATFORM_MACOS
        cfg.platform = ghostty_platform_u(macos: ghostty_platform_macos_s(nsview: Unmanaged.passUnretained(self).toOpaque()))
        cfg.scale_factor = scale
        cfg.font_size = Float(ConfigStore.shared.fontSize)
        cfg.context = GHOSTTY_SURFACE_CONTEXT_TAB

        let keys = Array(options.environment.keys)
        let cKeys = keys.map { strdup($0) }
        let cValues = keys.map { strdup(options.environment[$0]!) }
        defer { (cKeys + cValues).forEach { free($0) } }
        var env = zip(cKeys, cValues).map { ghostty_env_var_s(key: UnsafePointer($0), value: UnsafePointer($1)) }
        let cwd: UnsafeMutablePointer<CChar>? = options.workingDirectory.flatMap { strdup($0) }
        defer { free(cwd) }
        cfg.working_directory = cwd.map { UnsafePointer($0) }

        surface = env.withUnsafeMutableBufferPointer { buf in
            cfg.env_vars = buf.baseAddress
            cfg.env_var_count = buf.count
            return ghostty_surface_new(app, &cfg)
        }
        updateTrackingAreas()
        // Zoomed: mark the size as chosen so a config reload (light/dark switch) keeps it.
        if ConfigStore.shared.zoom != 0 { fontSizeChanged() }
        NotificationCenter.default.addObserver(self, selector: #selector(fontSizeChanged), name: .terminalFontSizeChanged, object: nil)
    }

    @objc private func fontSizeChanged() {
        let ok = perform("set_font_size:\(ConfigStore.shared.fontSize)")
        Debug.log("font size \(ConfigStore.shared.fontSize): \(ok)")
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    deinit {
        if let surface { ghostty_surface_free(surface) }
    }

    // MARK: TerminalSurface

    func sendText(_ text: String) {
        guard let surface, !text.isEmpty else { return }
        text.withCString { ghostty_surface_text(surface, $0, UInt(strlen($0))) }
    }

    func paste(_ text: String) {
        guard let surface, !text.isEmpty else { return }
        text.withCString { ghostty_surface_paste_text(surface, $0, UInt(strlen($0))) }
    }

    func sendKey(_ key: TerminalKey) {
        switch key {
        case .enter: synthesizeKey(keyCode: 36, text: "\r", unshifted: 13)
        case .tab: synthesizeKey(keyCode: 48, text: "\t", unshifted: 9)
        case .escape: synthesizeKey(keyCode: 53, text: nil, unshifted: 27)
        case .interrupt: synthesizeKey(keyCode: 8, text: "c", unshifted: 99, mods: GHOSTTY_MODS_CTRL)
        case .endOfFile: synthesizeKey(keyCode: 2, text: "d", unshifted: 100, mods: GHOSTTY_MODS_CTRL)
        case .clearScreen: perform("clear_screen")
        }
    }

    private func synthesizeKey(keyCode: UInt32, text: String?, unshifted: UInt32, mods: ghostty_input_mods_e = GHOSTTY_MODS_NONE) {
        guard let surface else { return }
        for action in [GHOSTTY_ACTION_PRESS, GHOSTTY_ACTION_RELEASE] {
            var ev = ghostty_input_key_s()
            ev.action = action
            ev.keycode = keyCode
            ev.mods = mods
            ev.consumed_mods = GHOSTTY_MODS_NONE
            ev.unshifted_codepoint = unshifted
            ev.composing = false
            if let text, action == GHOSTTY_ACTION_PRESS {
                text.withCString { ptr in
                    ev.text = ptr
                    _ = ghostty_surface_key(surface, ev)
                }
            } else {
                ev.text = nil
                _ = ghostty_surface_key(surface, ev)
            }
        }
    }

    @discardableResult
    func perform(_ action: String) -> Bool {
        guard let surface else { return false }
        return ghostty_surface_binding_action(surface, action, UInt(action.utf8.count))
    }

    func focus() { window?.makeFirstResponder(self) }

    var hasSelection: Bool {
        guard let surface else { return false }
        return ghostty_surface_has_selection(surface)
    }

    func setOccluded(_ occluded: Bool) {
        guard let surface else { return }
        ghostty_surface_set_occlusion(surface, !occluded)
    }

    func close() {
        guard let surface else { return }
        ghostty_surface_request_close(surface)
    }

    // MARK: Sizing and display

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        pushSize()
    }

    private func pushSize() {
        guard let surface, bounds.width > 0, bounds.height > 0 else { return }
        let px = convertToBacking(bounds.size)
        ghostty_surface_set_size(surface, UInt32(px.width), UInt32(px.height))
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        guard let surface, let window else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.contentsScale = window.backingScaleFactor
        CATransaction.commit()
        let fb = convertToBacking(bounds)
        if bounds.width > 0 {
            ghostty_surface_set_content_scale(surface, fb.width / bounds.width, fb.height / bounds.height)
        }
        pushSize()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        viewDidChangeBackingProperties()
        updateDisplayID()
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSWindow.didChangeScreenNotification, object: window)
    }

    @objc private func screenChanged() { updateDisplayID() }

    private func updateDisplayID() {
        guard let surface, let screen = window?.screen,
              let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 else { return }
        ghostty_surface_set_display_id(surface, id)
    }

    // MARK: Focus

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok, let surface { ghostty_surface_set_focus(surface, true) }
        return ok
    }

    override func resignFirstResponder() -> Bool {
        let ok = super.resignFirstResponder()
        if ok, let surface { ghostty_surface_set_focus(surface, false) }
        return ok
    }

    // MARK: Mouse

    override func updateTrackingAreas() {
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .inVisibleRect, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
        super.updateTrackingAreas()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if window?.firstResponder !== self { window?.makeFirstResponder(self) }
        mouseButton(GHOSTTY_MOUSE_PRESS, GHOSTTY_MOUSE_LEFT, event)
    }
    override func mouseUp(with event: NSEvent) { mouseButton(GHOSTTY_MOUSE_RELEASE, GHOSTTY_MOUSE_LEFT, event) }
    override func rightMouseDown(with event: NSEvent) {
        if !mouseButton(GHOSTTY_MOUSE_PRESS, GHOSTTY_MOUSE_RIGHT, event) { super.rightMouseDown(with: event) }
    }
    override func rightMouseUp(with event: NSEvent) { mouseButton(GHOSTTY_MOUSE_RELEASE, GHOSTTY_MOUSE_RIGHT, event) }
    override func otherMouseDown(with event: NSEvent) { mouseButton(GHOSTTY_MOUSE_PRESS, GHOSTTY_MOUSE_MIDDLE, event) }
    override func otherMouseUp(with event: NSEvent) { mouseButton(GHOSTTY_MOUSE_RELEASE, GHOSTTY_MOUSE_MIDDLE, event) }

    @discardableResult
    private func mouseButton(_ state: ghostty_input_mouse_state_e, _ button: ghostty_input_mouse_button_e, _ event: NSEvent) -> Bool {
        guard let surface else { return false }
        mouseMoved(with: event)
        return ghostty_surface_mouse_button(surface, state, button, Self.mods(event.modifierFlags))
    }

    override func mouseMoved(with event: NSEvent) {
        guard let surface else { return }
        let pos = convert(event.locationInWindow, from: nil)
        ghostty_surface_mouse_pos(surface, pos.x, bounds.height - pos.y, Self.mods(event.modifierFlags))
    }
    override func mouseDragged(with event: NSEvent) { mouseMoved(with: event) }
    override func rightMouseDragged(with event: NSEvent) { mouseMoved(with: event) }
    override func otherMouseDragged(with event: NSEvent) { mouseMoved(with: event) }

    override func mouseExited(with event: NSEvent) {
        guard let surface, NSEvent.pressedMouseButtons == 0 else { return }
        ghostty_surface_mouse_pos(surface, -1, -1, Self.mods(event.modifierFlags))
    }

    override func scrollWheel(with event: NSEvent) {
        guard let surface else { return }
        var x = event.scrollingDeltaX
        var y = event.scrollingDeltaY
        let precise = event.hasPreciseScrollingDeltas
        if precise { x *= 2; y *= 2 }
        var mods: Int32 = precise ? 1 : 0
        let momentum: Int32
        switch event.momentumPhase {
        case .began: momentum = 1
        case .stationary: momentum = 2
        case .changed: momentum = 3
        case .ended: momentum = 4
        case .cancelled: momentum = 5
        case .mayBegin: momentum = 6
        default: momentum = 0
        }
        mods |= momentum << 1
        ghostty_surface_mouse_scroll(surface, x, y, ghostty_input_scroll_mods_t(mods))
    }

    func setCursorShape(_ shape: ghostty_action_mouse_shape_e) {
        switch shape {
        case GHOSTTY_MOUSE_SHAPE_TEXT: NSCursor.iBeam.set()
        case GHOSTTY_MOUSE_SHAPE_POINTER: NSCursor.pointingHand.set()
        case GHOSTTY_MOUSE_SHAPE_CROSSHAIR: NSCursor.crosshair.set()
        default: NSCursor.arrow.set()
        }
    }

    // MARK: Keyboard

    static func mods(_ flags: NSEvent.ModifierFlags) -> ghostty_input_mods_e {
        var m: UInt32 = GHOSTTY_MODS_NONE.rawValue
        if flags.contains(.shift) { m |= GHOSTTY_MODS_SHIFT.rawValue }
        if flags.contains(.control) { m |= GHOSTTY_MODS_CTRL.rawValue }
        if flags.contains(.option) { m |= GHOSTTY_MODS_ALT.rawValue }
        if flags.contains(.command) { m |= GHOSTTY_MODS_SUPER.rawValue }
        if flags.contains(.capsLock) { m |= GHOSTTY_MODS_CAPS.rawValue }
        let raw = flags.rawValue
        if raw & UInt(NX_DEVICERSHIFTKEYMASK) != 0 { m |= GHOSTTY_MODS_SHIFT_RIGHT.rawValue }
        if raw & UInt(NX_DEVICERCTLKEYMASK) != 0 { m |= GHOSTTY_MODS_CTRL_RIGHT.rawValue }
        if raw & UInt(NX_DEVICERALTKEYMASK) != 0 { m |= GHOSTTY_MODS_ALT_RIGHT.rawValue }
        if raw & UInt(NX_DEVICERCMDKEYMASK) != 0 { m |= GHOSTTY_MODS_SUPER_RIGHT.rawValue }
        return ghostty_input_mods_e(m)
    }

    private static func flags(_ mods: ghostty_input_mods_e) -> NSEvent.ModifierFlags {
        var f: NSEvent.ModifierFlags = []
        if mods.rawValue & GHOSTTY_MODS_SHIFT.rawValue != 0 { f.insert(.shift) }
        if mods.rawValue & GHOSTTY_MODS_CTRL.rawValue != 0 { f.insert(.control) }
        if mods.rawValue & GHOSTTY_MODS_ALT.rawValue != 0 { f.insert(.option) }
        if mods.rawValue & GHOSTTY_MODS_SUPER.rawValue != 0 { f.insert(.command) }
        return f
    }

    private func keyEvent(_ action: ghostty_input_action_e, _ event: NSEvent, translationMods: NSEvent.ModifierFlags? = nil) -> ghostty_input_key_s {
        var ev = ghostty_input_key_s()
        ev.action = action
        ev.keycode = UInt32(event.keyCode)
        ev.text = nil
        ev.composing = false
        ev.mods = Self.mods(event.modifierFlags)
        ev.consumed_mods = Self.mods((translationMods ?? event.modifierFlags).subtracting([.control, .command]))
        ev.unshifted_codepoint = 0
        if event.type == .keyDown || event.type == .keyUp,
           let chars = event.characters(byApplyingModifiers: []), let cp = chars.unicodeScalars.first {
            ev.unshifted_codepoint = cp.value
        }
        return ev
    }

    /// Text for a key event, without control characters (libghostty encodes those).
    private static func characters(_ event: NSEvent) -> String? {
        guard let chars = event.characters else { return nil }
        if chars.count == 1, let s = chars.unicodeScalars.first {
            if s.value < 0x20 { return event.characters(byApplyingModifiers: event.modifierFlags.subtracting(.control)) }
            if s.value >= 0xF700 && s.value <= 0xF8FF { return nil }
        }
        return chars
    }

    @discardableResult
    private func keyAction(_ action: ghostty_input_action_e, event: NSEvent, translationEvent: NSEvent? = nil, text: String? = nil, composing: Bool = false) -> Bool {
        guard let surface else { return false }
        var ev = keyEvent(action, event, translationMods: translationEvent?.modifierFlags)
        ev.composing = composing
        if let text, !text.isEmpty, !(text.count == 1 && (text.unicodeScalars.first?.value ?? 0x20) < 0x20) {
            return text.withCString { ptr in
                ev.text = ptr
                return ghostty_surface_key(surface, ev)
            }
        }
        return ghostty_surface_key(surface, ev)
    }

    override func keyDown(with event: NSEvent) {
        guard let surface else { interpretKeyEvents([event]); return }
        delegate?.surfaceDidReceiveKeyInput(self)

        let ghosttyTranslation = Self.flags(ghostty_surface_key_translation_mods(surface, Self.mods(event.modifierFlags)))
        var translationMods = event.modifierFlags
        for flag in [NSEvent.ModifierFlags.shift, .control, .option, .command] {
            if ghosttyTranslation.contains(flag) { translationMods.insert(flag) } else { translationMods.remove(flag) }
        }
        let translationEvent: NSEvent = translationMods == event.modifierFlags ? event : (NSEvent.keyEvent(
            with: event.type, location: event.locationInWindow, modifierFlags: translationMods,
            timestamp: event.timestamp, windowNumber: event.windowNumber, context: nil,
            characters: event.characters(byApplyingModifiers: translationMods) ?? "",
            charactersIgnoringModifiers: event.charactersIgnoringModifiers ?? "",
            isARepeat: event.isARepeat, keyCode: event.keyCode) ?? event)

        let action = event.isARepeat ? GHOSTTY_ACTION_REPEAT : GHOSTTY_ACTION_PRESS
        keyTextAccumulator = []
        defer { keyTextAccumulator = nil }
        let markedBefore = markedText.length > 0
        lastPerformKeyEvent = nil

        interpretKeyEvents([translationEvent])

        syncPreedit(clearIfNeeded: markedBefore)
        let composing = markedText.length > 0 || markedBefore

        if let list = keyTextAccumulator, !list.isEmpty {
            for text in list { keyAction(action, event: event, translationEvent: translationEvent, text: text) }
        } else {
            keyAction(action, event: event, translationEvent: translationEvent, text: Self.characters(translationEvent), composing: composing)
        }
    }

    override func keyUp(with event: NSEvent) {
        keyAction(GHOSTTY_ACTION_RELEASE, event: event)
    }

    override func flagsChanged(with event: NSEvent) {
        let mod: UInt32
        switch event.keyCode {
        case 0x39: mod = GHOSTTY_MODS_CAPS.rawValue
        case 0x38, 0x3C: mod = GHOSTTY_MODS_SHIFT.rawValue
        case 0x3B, 0x3E: mod = GHOSTTY_MODS_CTRL.rawValue
        case 0x3A, 0x3D: mod = GHOSTTY_MODS_ALT.rawValue
        case 0x37, 0x36: mod = GHOSTTY_MODS_SUPER.rawValue
        default: return
        }
        if hasMarkedText() { return }
        let pressed = Self.mods(event.modifierFlags).rawValue & mod != 0
        keyAction(pressed ? GHOSTTY_ACTION_PRESS : GHOSTTY_ACTION_RELEASE, event: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown, window?.firstResponder === self else { return false }
        // Ctrl+Return and Ctrl+/ would otherwise beep or be swallowed by AppKit.
        if event.modifierFlags.contains(.control), !event.modifierFlags.contains(.command),
           let c = event.charactersIgnoringModifiers, c == "\r" || c == "/" {
            keyDown(with: event)
            return true
        }
        // Command keys go to the menu first; if nothing handles them, AppKit
        // sends keyDown and they are encoded for the program.
        if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) {
            if let last = lastPerformKeyEvent, last == event.timestamp, event.timestamp != 0 {
                lastPerformKeyEvent = nil
                keyDown(with: event)
                return true
            }
            lastPerformKeyEvent = event.timestamp
        }
        return false
    }

    override func doCommand(by selector: Selector) {
        if let last = lastPerformKeyEvent, let current = NSApp.currentEvent, last == current.timestamp {
            NSApp.sendEvent(current)
        }
    }

    // MARK: Copy / paste from the Edit menu

    @objc func copy(_ sender: Any?) { perform("copy_to_clipboard") }
    @objc func paste(_ sender: Any?) { perform("paste_from_clipboard") }
    @objc override func selectAll(_ sender: Any?) { perform("select_all") }

    private func syncPreedit(clearIfNeeded: Bool = true) {
        guard let surface else { return }
        if markedText.length > 0 {
            let str = markedText.string
            str.withCString { ghostty_surface_preedit(surface, $0, UInt(strlen($0))) }
        } else if clearIfNeeded {
            ghostty_surface_preedit(surface, nil, 0)
        }
    }
}

// MARK: - NSTextInputClient (IME, accents, emoji picker)

extension TerminalSurfaceView: NSTextInputClient {
    func hasMarkedText() -> Bool { markedText.length > 0 }
    func markedRange() -> NSRange { markedText.length > 0 ? NSRange(location: 0, length: markedText.length) : NSRange() }
    func selectedRange() -> NSRange { NSRange() }
    func validAttributesForMarkedText() -> [NSAttributedString.Key] { [] }
    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? { nil }
    func characterIndex(for point: NSPoint) -> Int { 0 }

    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        switch string {
        case let v as NSAttributedString: markedText = NSMutableAttributedString(attributedString: v)
        case let v as String: markedText = NSMutableAttributedString(string: v)
        default: break
        }
        if keyTextAccumulator == nil { syncPreedit() }
    }

    func unmarkText() {
        if markedText.length > 0 {
            markedText.mutableString.setString("")
            syncPreedit()
        }
    }

    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        guard let surface else { return .zero }
        var x = 0.0, y = 0.0, w = Double(cellSize.width), h = Double(cellSize.height)
        ghostty_surface_ime_point(surface, &x, &y, &w, &h)
        let rect = NSRect(x: x, y: bounds.height - y, width: range.length == 0 ? 0 : w, height: max(h, cellSize.height))
        guard let window else { return rect }
        return window.convertToScreen(convert(rect, to: nil))
    }

    func insertText(_ string: Any, replacementRange: NSRange) {
        guard NSApp.currentEvent != nil else { return }
        let chars: String
        switch string {
        case let v as NSAttributedString: chars = v.string
        case let v as String: chars = v
        default: return
        }
        unmarkText()
        if var acc = keyTextAccumulator {
            acc.append(chars)
            keyTextAccumulator = acc
            return
        }
        guard let surface, !chars.isEmpty else { return }
        var ev = ghostty_input_key_s()
        ev.action = GHOSTTY_ACTION_PRESS
        ev.mods = GHOSTTY_MODS_NONE
        ev.consumed_mods = GHOSTTY_MODS_NONE
        chars.withCString { ptr in
            ev.text = ptr
            _ = ghostty_surface_key(surface, ev)
        }
    }
}
