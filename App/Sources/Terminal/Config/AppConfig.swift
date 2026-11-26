import AppKit

/// The one config file: `~/.config/terminal/config`, `key = value` lines like Ghostty.
/// Keys this app owns are read here; every other line is passed to libghostty,
/// so Ghostty options (fonts, colours, themes…) work as-is.
struct AppConfig {
    enum Edge: String { case top, bottom, left, right, center }
    enum ScreenChoice: String { case mouse, main }
    enum Size: Equatable {
        case percent(Double)
        case pixels(Double)

        init?(_ text: String) {
            let t = text.trimmingCharacters(in: .whitespaces)
            if t.hasSuffix("%"), let v = Double(t.dropLast()) { self = .percent(v / 100) }
            else if let v = Double(t.replacingOccurrences(of: "px", with: "")) { self = .pixels(v) }
            else { return nil }
        }

        func resolve(in length: CGFloat) -> CGFloat {
            switch self {
            case .percent(let p): return length * p
            case .pixels(let px): return min(px, length)
            }
        }
    }

    // Hotkey window (specs/03-hotkey-window.md)
    var hotkey = "cmd+shift+backslash"
    var hotkeyPosition = Edge.top
    var hotkeyHeight = Size.percent(0.45)
    var hotkeyWidth = Size.percent(1)
    var hotkeyScreen = ScreenChoice.mouse
    var hotkeyAutohide = true
    var hotkeyAnimation = 0.12

    // App behaviour
    var launchAtLogin = false
    var smartInput = true
    var historyImport = true

    /// Lines forwarded to libghostty, after our defaults.
    var ghosttyLines: [String] = []

    /// Defaults for the look (specs/02-look.md). The user's own lines come after
    /// and win. `shell-integration` and `keybind` are forced: the app injects its
    /// own shell integration and owns the shortcuts.
    static let defaultFontSize = 12.0

    static let ghosttyDefaults = """
    theme = light:GitHub Light Default,dark:GitHub Dark Default
    font-size = \(Int(defaultFontSize))
    window-padding-x = 16
    window-padding-y = 12
    window-padding-balance = true
    window-padding-color = extend
    background-opacity = 0.92
    background-blur = 20
    cursor-style = bar
    cursor-style-blink = true
    mouse-hide-while-typing = true
    confirm-close-surface = false
    copy-on-select = none
    """

    static let ghosttyForced = """
    shell-integration = none
    keybind = clear
    keybind = shift+page_up=scroll_page_up
    keybind = shift+page_down=scroll_page_down
    keybind = super+home=scroll_to_top
    keybind = super+end=scroll_to_bottom
    """

    static var fileURL: URL {
        let base = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config")
        return base.appendingPathComponent("terminal/config")
    }

    /// The config handed to libghostty for the current appearance.
    ///
    /// `theme = light:A,dark:B` is resolved here rather than by libghostty: a
    /// conditional theme makes libghostty rebuild every new surface's config
    /// from the file, which drops the per-surface options (env vars, command)
    /// the shell integration needs.
    func ghosttyConfigText(dark: Bool) -> String {
        let lines = Self.ghosttyDefaults.split(separator: "\n").map(String.init) + ghosttyLines + [Self.ghosttyForced]
        return lines.map { line in
            let p = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard p.count == 2, p[0] == "theme" else { return line }
            return "theme = " + Self.resolveTheme(p[1], dark: dark)
        }.joined(separator: "\n") + "\n"
    }

    /// `light:A,dark:B` → A or B. Any other value is returned as is.
    static func resolveTheme(_ value: String, dark: Bool) -> String {
        var light: String?, darkTheme: String?
        for part in value.split(separator: ",") {
            let p = part.trimmingCharacters(in: .whitespaces)
            if p.hasPrefix("light:") { light = String(p.dropFirst(6)).trimmingCharacters(in: .whitespaces) }
            if p.hasPrefix("dark:") { darkTheme = String(p.dropFirst(5)).trimmingCharacters(in: .whitespaces) }
        }
        guard light != nil || darkTheme != nil else { return value }
        return (dark ? darkTheme ?? light : light ?? darkTheme)!
    }

    static func load() -> AppConfig {
        let text = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        return parse(text)
    }

    static func parse(_ text: String) -> AppConfig {
        var c = AppConfig()
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces)
            var value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") { value = String(value.dropFirst().dropLast()) }
            if !c.apply(key: key, value: value) { c.ghosttyLines.append(line) }
        }
        return c
    }

    /// Returns false for keys that belong to libghostty.
    private mutating func apply(key: String, value: String) -> Bool {
        let bool = ["true", "yes", "on", "1"].contains(value.lowercased())
        switch key {
        case "hotkey": hotkey = value
        case "hotkey-position": hotkeyPosition = Edge(rawValue: value) ?? hotkeyPosition
        case "hotkey-height": hotkeyHeight = Size(value) ?? hotkeyHeight
        case "hotkey-width": hotkeyWidth = Size(value) ?? hotkeyWidth
        case "hotkey-screen": hotkeyScreen = ScreenChoice(rawValue: value) ?? hotkeyScreen
        case "hotkey-autohide": hotkeyAutohide = bool
        case "hotkey-animation": hotkeyAnimation = value.lowercased() == "false" ? 0 : (Double(value) ?? hotkeyAnimation)
        case "launch-at-login": launchAtLogin = bool
        case "smart-input": smartInput = bool
        case "history-import": historyImport = bool
        // Owned by the app: ignore so the user can't break the integration.
        case "shell-integration", "keybind": return true
        default: return false
        }
        return true
    }

    /// Writes a commented starter file the first time the app runs.
    static func writeStarterIfMissing() {
        let url = fileURL
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let starter = """
        # Terminal config. Reloaded when saved.
        # App options:
        # hotkey = cmd+shift+backslash
        # hotkey-position = top        # top, bottom, left, right, center
        # hotkey-height = 45%
        # hotkey-width = 100%
        # hotkey-screen = mouse        # mouse or main
        # hotkey-autohide = true
        # hotkey-animation = 0.12      # seconds, or false
        # launch-at-login = false
        # smart-input = true
        #
        # Any Ghostty option works too, for example:
        # theme = Catppuccin Mocha
        # font-family = JetBrains Mono
        # font-size = 12
        # background-opacity = 0.92

        """
        try? starter.write(to: url, atomically: true, encoding: .utf8)
    }
}

/// Watches the config file with a kernel event (no polling) and calls back on change.
final class ConfigWatcher {
    private var source: DispatchSourceFileSystemObject?
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        watch()
    }

    private func watch() {
        source?.cancel()
        let fd = open(AppConfig.fileURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
        src.setEventHandler { [weak self] in
            guard let self else { return }
            // Editors often replace the file: re-open the watch on rename/delete.
            if src.data.contains(.rename) || src.data.contains(.delete) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.watch() }
            }
            self.onChange()
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
    }
}
