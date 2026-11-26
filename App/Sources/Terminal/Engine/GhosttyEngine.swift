// The only place, with the other files in Engine/, that talks to libghostty's C API.
// Callers use `TerminalEngine` and `TerminalSurface` (see TerminalSurface.swift).
//
// Parts of the event plumbing are adapted from Ghostty's macOS app
// (MIT licence, see Vendor/ghostty/LICENSE).

import AppKit
import GhosttyKit

/// Colours the app needs to draw its own chrome around the terminal.
struct TerminalColors {
    var background: NSColor
    var foreground: NSColor
    var dim: NSColor
    var accent: NSColor
    var opacity: Double
}

extension Notification.Name {
    /// The terminal theme changed (light/dark switch or config reload).
    static let terminalThemeChanged = Notification.Name("terminalThemeChanged")
}

/// App-wide libghostty state: one `ghostty_app_t` for every surface.
final class TerminalEngine {
    static let shared = TerminalEngine()

    private(set) var app: ghostty_app_t?
    private var config: ghostty_config_t?
    private var tickScheduled = false

    private init() {}

    /// Starts libghostty. `configText` is a Ghostty-format config file body.
    func start(configText: String) {
        if let resources = Bundle.main.resourceURL?.appendingPathComponent("ghostty"),
           FileManager.default.fileExists(atPath: resources.path) {
            setenv("GHOSTTY_RESOURCES_DIR", resources.path, 1)
        }
        if ghostty_init(UInt(CommandLine.argc), CommandLine.unsafeArgv) != GHOSTTY_SUCCESS {
            fatalError("libghostty failed to initialise")
        }

        guard let cfg = makeConfig(configText) else { fatalError("libghostty config failed") }
        config = cfg

        var runtime = ghostty_runtime_config_s(
            userdata: Unmanaged.passUnretained(self).toOpaque(),
            supports_selection_clipboard: false,
            wakeup_cb: { _ in TerminalEngine.shared.scheduleTick() },
            action_cb: { app, target, action in TerminalEngine.handleAction(app, target: target, action: action) },
            read_clipboard_cb: { userdata, location, state, mimes, mimesLen, list in
                TerminalEngine.readClipboard(userdata, location: location, state: state, mimes: mimes, mimesLen: mimesLen, list: list)
            },
            confirm_read_clipboard_cb: { userdata, confirm, state, request in
                TerminalEngine.confirmReadClipboard(userdata, confirm: confirm, state: state, request: request)
            },
            write_clipboard_cb: { userdata, location, content, len, confirm in
                TerminalEngine.writeClipboard(userdata, location: location, content: content, len: len, confirm: confirm)
            },
            close_surface_cb: { userdata, processAlive in
                guard let view = TerminalEngine.surfaceView(userdata) else { return }
                DispatchQueue.main.async { view.delegate?.surfaceDidRequestClose(view, processAlive: processAlive) }
            }
        )

        guard let app = ghostty_app_new(&runtime, cfg) else { fatalError("ghostty_app_new failed") }
        self.app = app
        ghostty_app_set_focus(app, NSApp.isActive)

        let center = NotificationCenter.default
        center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            if let app = self?.app { ghostty_app_set_focus(app, true) }
        }
        center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            if let app = self?.app { ghostty_app_set_focus(app, false) }
        }
        center.addObserver(forName: NSTextInputContext.keyboardSelectionDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            if let app = self?.app { ghostty_app_keyboard_changed(app) }
        }
    }

    /// Applies a new config to every surface (live reload).
    func reload(configText: String) {
        guard let app, let cfg = makeConfig(configText) else { return }
        ghostty_app_update_config(app, cfg)
        if let old = config { ghostty_config_free(old) }
        config = cfg
        // The effective config from the last CONFIG_CHANGE is stale now; a new one follows.
        if let old = effectiveConfig { ghostty_config_free(old); effectiveConfig = nil }
    }

    private func makeConfig(_ text: String) -> ghostty_config_t? {
        guard let cfg = ghostty_config_new() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("terminal-ghostty-\(getpid()).conf")
        try? text.write(to: url, atomically: true, encoding: .utf8)
        ghostty_config_load_file(cfg, url.path)
        try? FileManager.default.removeItem(at: url)
        ghostty_config_finalize(cfg)
        let count = ghostty_config_diagnostics_count(cfg)
        for i in 0..<count {
            let diag = ghostty_config_get_diagnostic(cfg, i)
            if let msg = diag.message { NSLog("config: %@", String(cString: msg)) }
        }
        return cfg
    }

    // MARK: Ticking

    /// libghostty asks to be ticked from any thread; coalesce to one main-thread tick.
    func scheduleTick() {
        DispatchQueue.main.async { [self] in
            guard !tickScheduled else { return }
            tickScheduled = true
            DispatchQueue.main.async { [self] in
                tickScheduled = false
                if let app { ghostty_app_tick(app) }
            }
        }
    }

    // MARK: Config values

    var colors: TerminalColors {
        let bg = color("background") ?? NSColor(white: 0.08, alpha: 1)
        let fg = color("foreground") ?? .white
        var opacity: Double = 1
        if let config = effectiveConfig ?? config { _ = ghostty_config_get(config, &opacity, "background-opacity", UInt("background-opacity".utf8.count)) }
        return TerminalColors(
            background: bg,
            foreground: fg,
            dim: fg.withAlphaComponent(0.55),
            accent: paletteColor(4) ?? .systemBlue,
            opacity: opacity
        )
    }

    private func color(_ key: String) -> NSColor? {
        guard let config = effectiveConfig ?? config else { return nil }
        var c = ghostty_config_color_s()
        guard ghostty_config_get(config, &c, key, UInt(key.utf8.count)) else { return nil }
        return NSColor(srgbRed: CGFloat(c.r) / 255, green: CGFloat(c.g) / 255, blue: CGFloat(c.b) / 255, alpha: 1)
    }

    func paletteColor(_ index: Int) -> NSColor? {
        guard let config = effectiveConfig ?? config else { return nil }
        var palette = ghostty_config_palette_s()
        guard ghostty_config_get(config, &palette, "palette", UInt("palette".utf8.count)) else { return nil }
        let c = withUnsafeBytes(of: palette.colors) { raw in
            raw.bindMemory(to: ghostty_config_color_s.self)[index]
        }
        return NSColor(srgbRed: CGFloat(c.r) / 255, green: CGFloat(c.g) / 255, blue: CGFloat(c.b) / 255, alpha: 1)
    }

    /// Asks libghostty to apply the configured background blur to a window.
    func applyBlur(to window: NSWindow) {
        guard let app else { return }
        ghostty_set_window_background_blur(app, Unmanaged.passUnretained(window).toOpaque())
    }

    func setColorScheme(dark: Bool) {
        guard let app else { return }
        ghostty_app_set_color_scheme(app, dark ? GHOSTTY_COLOR_SCHEME_DARK : GHOSTTY_COLOR_SCHEME_LIGHT)
    }

    // MARK: Actions from libghostty

    static func surfaceView(_ userdata: UnsafeMutableRawPointer?) -> TerminalSurfaceView? {
        guard let userdata else { return nil }
        return Unmanaged<TerminalSurfaceView>.fromOpaque(userdata).takeUnretainedValue()
    }

    /// The config with conditional parts (light/dark theme) applied, as libghostty last reported it.
    private var effectiveConfig: ghostty_config_t?

    private static func handleAction(_ app: ghostty_app_t?, target: ghostty_target_s, action: ghostty_action_s) -> Bool {
        if action.tag == GHOSTTY_ACTION_CONFIG_CHANGE, target.tag == GHOSTTY_TARGET_APP,
           let cfg = action.action.config_change.config, let clone = ghostty_config_clone(cfg) {
            DispatchQueue.main.async {
                let engine = TerminalEngine.shared
                if let old = engine.effectiveConfig { ghostty_config_free(old) }
                engine.effectiveConfig = clone
                NotificationCenter.default.post(name: .terminalThemeChanged, object: nil)
            }
            return true
        }
        guard target.tag == GHOSTTY_TARGET_SURFACE,
              let surface = target.target.surface,
              let view = surfaceView(ghostty_surface_userdata(surface)) else {
            return false
        }

        switch action.tag {
        case GHOSTTY_ACTION_SET_TITLE:
            guard let title = action.action.set_title.title.map({ String(cString: $0) }) else { return false }
            DispatchQueue.main.async { view.delegate?.surface(view, didChangeTitle: title) }
            return true

        case GHOSTTY_ACTION_PWD:
            guard let pwd = action.action.pwd.pwd.map({ String(cString: $0) }) else { return false }
            DispatchQueue.main.async { view.delegate?.surface(view, didReportDirectory: pwd) }
            return true

        case GHOSTTY_ACTION_COMMAND_FINISHED:
            let v = action.action.command_finished
            let exit: Int? = v.exit_code < 0 ? nil : Int(v.exit_code)
            let ms = Int(v.duration / 1_000_000)
            DispatchQueue.main.async { view.delegate?.surface(view, didFinishCommandWithExitCode: exit, durationMs: ms) }
            return true

        case GHOSTTY_ACTION_SHOW_CHILD_EXITED:
            DispatchQueue.main.async { view.delegate?.surfaceDidRequestClose(view, processAlive: false) }
            return true

        case GHOSTTY_ACTION_RING_BELL:
            DispatchQueue.main.async { view.delegate?.surfaceDidRingBell(view) }
            return true

        case GHOSTTY_ACTION_MOUSE_SHAPE:
            let shape = action.action.mouse_shape
            DispatchQueue.main.async { view.setCursorShape(shape) }
            return true

        case GHOSTTY_ACTION_MOUSE_VISIBILITY:
            let hidden = action.action.mouse_visibility == GHOSTTY_MOUSE_HIDDEN
            DispatchQueue.main.async { NSCursor.setHiddenUntilMouseMoves(hidden) }
            return true

        case GHOSTTY_ACTION_OPEN_URL:
            let v = action.action.open_url
            guard let ptr = v.url else { return false }
            let data = Data(bytes: ptr, count: Int(v.len))
            guard let str = String(data: data, encoding: .utf8) else { return false }
            let url = URL(string: str) ?? URL(fileURLWithPath: str)
            DispatchQueue.main.async { NSWorkspace.shared.open(url) }
            return true

        case GHOSTTY_ACTION_CELL_SIZE:
            let v = action.action.cell_size
            DispatchQueue.main.async {
                view.cellSize = CGSize(width: CGFloat(v.width) / view.scale, height: CGFloat(v.height) / view.scale)
            }
            return true

        case GHOSTTY_ACTION_RENDER, GHOSTTY_ACTION_RENDERER_HEALTH, GHOSTTY_ACTION_SCROLLBAR,
             GHOSTTY_ACTION_SIZE_LIMIT, GHOSTTY_ACTION_INITIAL_SIZE, GHOSTTY_ACTION_COLOR_CHANGE,
             GHOSTTY_ACTION_CONFIG_CHANGE, GHOSTTY_ACTION_SELECTION_CHANGED, GHOSTTY_ACTION_PROGRESS_REPORT,
             GHOSTTY_ACTION_MOUSE_OVER_LINK, GHOSTTY_ACTION_KEY_SEQUENCE, GHOSTTY_ACTION_KEY_TABLE:
            return true

        default:
            return false
        }
    }

    // MARK: Clipboard

    private static func readClipboard(
        _ userdata: UnsafeMutableRawPointer?,
        location: ghostty_clipboard_e,
        state: UnsafeMutableRawPointer?,
        mimes: UnsafePointer<UnsafePointer<CChar>?>?,
        mimesLen: Int,
        list: Bool
    ) -> ghostty_clipboard_read_result_e {
        guard location == GHOSTTY_CLIPBOARD_STANDARD,
              let view = surfaceView(userdata), let surface = view.surface else {
            return GHOSTTY_CLIPBOARD_READ_UNSUPPORTED
        }
        guard let text = NSPasteboard.general.string(forType: .string) else {
            return GHOSTTY_CLIPBOARD_READ_UNAVAILABLE
        }
        complete(surface, text: text, state: state, confirmed: false)
        return GHOSTTY_CLIPBOARD_READ_STARTED
    }

    private static func confirmReadClipboard(
        _ userdata: UnsafeMutableRawPointer?,
        confirm: UnsafePointer<ghostty_clipboard_confirm_s>?,
        state: UnsafeMutableRawPointer?,
        request: ghostty_clipboard_request_e
    ) {
        guard let view = surfaceView(userdata), let surface = view.surface else { return }
        // Programs reading the clipboard (OSC 52) are always denied: lean and safe.
        guard request == GHOSTTY_CLIPBOARD_REQUEST_PASTE, let confirm,
              let contents = confirm.pointee.contents, confirm.pointee.contents_len > 0,
              let data = contents[0].data else {
            ghostty_surface_deny_clipboard_request(surface, state)
            return
        }
        let text = String(decoding: Data(bytes: data, count: contents[0].len), as: UTF8.self)
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Paste text that may run commands?"
            alert.informativeText = String(text.prefix(400))
            alert.addButton(withTitle: "Paste")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                complete(surface, text: text, state: state, confirmed: true)
            } else {
                ghostty_surface_deny_clipboard_request(surface, state)
            }
        }
    }

    private static func complete(_ surface: ghostty_surface_t, text: String, state: UnsafeMutableRawPointer?, confirmed: Bool) {
        let mime = strdup("text/plain")
        let bytes = Array(text.utf8)
        defer { free(mime) }
        bytes.withUnsafeBufferPointer { buf in
            buf.withMemoryRebound(to: CChar.self) { cbuf in
                var content = ghostty_clipboard_content_s(mime: mime, data: cbuf.baseAddress, len: bytes.count)
                withUnsafePointer(to: &content) { contentPtr in
                    var done = ghostty_clipboard_complete_s(
                        contents: contentPtr, contents_len: 1,
                        available: nil, available_len: 0,
                        confirmed: confirmed, remember: false)
                    ghostty_surface_complete_clipboard_request(surface, &done, state)
                }
            }
        }
    }

    private static func writeClipboard(
        _ userdata: UnsafeMutableRawPointer?,
        location: ghostty_clipboard_e,
        content: UnsafePointer<ghostty_clipboard_content_s>?,
        len: Int,
        confirm: Bool
    ) {
        // Writes that need confirmation come from programs (OSC 52); skip them.
        guard location == GHOSTTY_CLIPBOARD_STANDARD, !confirm, let content else { return }
        for i in 0..<len {
            let item = content[i]
            guard let mime = item.mime, String(cString: mime) == "text/plain", let data = item.data else { continue }
            let text = String(decoding: Data(bytes: data, count: item.len), as: UTF8.self)
            DispatchQueue.main.async {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
            return
        }
    }
}
