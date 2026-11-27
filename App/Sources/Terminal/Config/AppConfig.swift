import AppKit

/// The one config file: `~/.config/terminal/config`, `key = value` lines like Ghostty.
/// Keys this app owns are read here; every other line is passed to libghostty,
/// so Ghostty options (fonts, colours, themes…) work as-is.
struct AppConfig {
    enum Edge: String { case top, bottom, left, right, center }
    enum ScreenChoice: String { case mouse, main }
    enum TabsPosition: String, CaseIterable { case left, right, top }
    /// Dock icon and ⌘⇥ switcher: `auto` shows them only while a normal window is open.
    enum DockIcon: String, CaseIterable { case auto, always, never }
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
    var hotkeyEnabled = true
    var hotkey = "cmd+shift+backslash"
    var hotkeyPosition = Edge.top
    var hotkeyHeight = Size.percent(0.45)
    var hotkeyWidth = Size.percent(1)
    var hotkeyScreen = ScreenChoice.mouse
    var hotkeyAutohide = true
    var hotkeyAnimation = 0.12

    // Tabs (specs/02-look.md): a sidebar on the left by default.
    var tabsPosition = TabsPosition.left
    var tabsWidth: CGFloat = 220
    static let tabsWidthRange: ClosedRange<CGFloat> = 140...420

    // App behaviour
    var dockIcon = DockIcon.auto
    var launchAtLogin = false
    var smartInput = true
    var historyImport = true
    /// Shell for new tabs: a path, or empty for the login shell (specs/09-settings.md).
    var shell = ""

    /// Lines forwarded to libghostty, after our defaults.
    var ghosttyLines: [String] = []

    /// Defaults for the look (specs/02-look.md). The user's own lines come after
    /// and win. `shell-integration` and `keybind` are forced: the app injects its
    /// own shell integration and owns the shortcuts.
    static let defaultFontSize = 12.0

    static let defaultTheme = "midnight"

    /// Built-in themes (specs/09-settings.md), as Ghostty lines. Tune colours here.
    /// `auto` follows the system: paper when light, midnight when dark.
    static let builtinThemes: [(name: String, title: String, lines: [String])] = [
        ("midnight", "Midnight", ["theme = GitHub Dark Default", "background = 0e0e0e", "foreground = d4d4d4"]),
        ("graphite", "Graphite", ["theme = Tomorrow Night", "background = 1c1c1e", "foreground = c8c8c8"]),
        ("frost", "Frost", ["theme = Nord"]),
        ("paper", "Paper", ["theme = GitHub Light Default"]),
        ("auto", "Match system", []),
    ]

    /// Swatch colours for the theme picker: background, text, accent (hex).
    static let themePreviews: [String: (bg: String, fg: String, accent: String)] = [
        "midnight": ("0e0e0e", "d4d4d4", "58a6ff"),
        "graphite": ("1c1c1e", "c8c8c8", "81a2be"),
        "frost": ("2e3440", "d8dee9", "88c0d0"),
        "paper": ("ffffff", "24292f", "0969da"),
    ]

    static let ghosttyDefaults = """
    font-size = \(Int(defaultFontSize))
    window-padding-x = 16
    window-padding-y = 12
    window-padding-balance = true
    window-padding-color = extend
    background-opacity = 0.9
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
    ///
    /// Only the last `theme` line counts. Its lines go right after the defaults,
    /// so the user's own colour lines still win over a built-in theme.
    func ghosttyConfigText(dark: Bool) -> String {
        let defaults = Self.ghosttyDefaults.split(separator: "\n").map(String.init)
        let user = ghosttyLines.filter { Self.key(of: $0) != "theme" }
        let lines = defaults + Self.themeLines(theme, dark: dark) + user + [Self.ghosttyForced]
        return lines.joined(separator: "\n") + "\n"
    }

    /// The theme the user picked: a built-in name, a Ghostty theme, or `light:A,dark:B`.
    var theme: String {
        ghosttyLines.last { Self.key(of: $0) == "theme" }.flatMap(Self.value(of:)) ?? Self.defaultTheme
    }

    static func themeLines(_ value: String, dark: Bool) -> [String] {
        var name = resolveTheme(value, dark: dark)
        if name == "auto" { name = dark ? "midnight" : "paper" }
        if let builtin = builtinThemes.first(where: { $0.name == name }) { return builtin.lines }
        return ["theme = " + name]
    }

    static func key(of line: String) -> String? {
        guard let eq = line.firstIndex(of: "=") else { return nil }
        return line[..<eq].trimmingCharacters(in: .whitespaces)
    }

    static func value(of line: String) -> String? {
        guard let eq = line.firstIndex(of: "=") else { return nil }
        var v = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
        if v.count >= 2, v.hasPrefix("\""), v.hasSuffix("\"") { v = String(v.dropFirst().dropLast()) }
        return v
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

    /// Sets `key = value` in the config file (nil removes it), keeping every
    /// other line and comment as typed. The file watcher then reloads the app.
    static func update(_ key: String, to value: String?) {
        writeStarterIfMissing()
        let text = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        var lines = text.components(separatedBy: "\n")
        let matches = lines.indices.filter {
            let l = lines[$0].trimmingCharacters(in: .whitespaces)
            return !l.hasPrefix("#") && self.key(of: l) == key
        }
        let newLine = value.map { "\(key) = \($0)" }
        if let last = matches.last {
            // Drop earlier duplicates: the last one is the one that counts.
            for i in matches.dropLast().reversed() { lines.remove(at: i) }
            let at = last - (matches.count - 1)
            if let newLine { lines[at] = newLine } else { lines.remove(at: at) }
        } else if let newLine {
            if lines.last == "" { lines.insert(newLine, at: lines.count - 1) } else { lines.append(newLine) }
        }
        try? lines.joined(separator: "\n").write(to: fileURL, atomically: true, encoding: .utf8)
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
        case "hotkey-enabled": hotkeyEnabled = bool
        case "dock-icon": dockIcon = DockIcon(rawValue: value) ?? dockIcon
        case "hotkey-position": hotkeyPosition = Edge(rawValue: value) ?? hotkeyPosition
        case "hotkey-height": hotkeyHeight = Size(value) ?? hotkeyHeight
        case "hotkey-width": hotkeyWidth = Size(value) ?? hotkeyWidth
        case "hotkey-screen": hotkeyScreen = ScreenChoice(rawValue: value) ?? hotkeyScreen
        case "hotkey-autohide": hotkeyAutohide = bool
        case "hotkey-animation": hotkeyAnimation = value.lowercased() == "false" ? 0 : (Double(value) ?? hotkeyAnimation)
        case "launch-at-login": launchAtLogin = bool
        case "smart-input": smartInput = bool
        case "shell": shell = value == "auto" ? "" : value
        case "history-import": historyImport = bool
        case "tabs-position": tabsPosition = TabsPosition(rawValue: value) ?? tabsPosition
        case "tabs-width":
            if let w = Double(value) { tabsWidth = min(max(CGFloat(w), Self.tabsWidthRange.lowerBound), Self.tabsWidthRange.upperBound) }
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
        # theme = midnight            # midnight, graphite, frost, paper, auto, or any Ghostty theme
        # tabs-position = left         # left, right or top
        # tabs-width = 220
        # hotkey-enabled = true
        # hotkey = cmd+shift+backslash
        # hotkey-position = top        # top, bottom, left, right, center
        # hotkey-height = 45%
        # hotkey-width = 100%
        # hotkey-screen = mouse        # mouse or main
        # hotkey-autohide = true
        # hotkey-animation = 0.12      # seconds, or false
        # dock-icon = auto             # auto (only while a window is open), always, never
        # launch-at-login = false
        # smart-input = true
        # shell = auto                 # or a path: /bin/bash, /opt/homebrew/bin/fish…
        #
        # Any Ghostty option works too, for example:
        # font-family = JetBrains Mono
        # font-size = 12
        # background-opacity = 0.9

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

// MARK: - Shells

enum Shells {
    /// Where shells live besides /etc/shells (Homebrew on Apple silicon and Intel).
    static let extraPaths = ["/opt/homebrew/bin", "/usr/local/bin"]
    static let extraNames = ["zsh", "bash", "fish", "nu", "xonsh", "elvish"]

    /// The user's login shell (from the user database, not $SHELL).
    static var login: String {
        if let pw = getpwuid(getuid()), let shell = pw.pointee.pw_shell { return String(cString: shell) }
        return ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    }

    /// Installed shells: /etc/shells, then the usual Homebrew ones. Only executables.
    static func available() -> [String] {
        let listed = (try? String(contentsOfFile: "/etc/shells", encoding: .utf8)).map(parse) ?? []
        let extra = extraPaths.flatMap { dir in extraNames.map { "\(dir)/\($0)" } }
        var seen = Set<String>()
        return (listed + extra).filter { FileManager.default.isExecutableFile(atPath: $0) && seen.insert($0).inserted }
    }

    /// Paths from an /etc/shells file (comments and blank lines skipped).
    static func parse(_ text: String) -> [String] {
        text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.hasPrefix("/") }
    }

    /// The shell new tabs run: the configured one if it can run, else the login shell.
    static func resolved(_ configured: String) -> String {
        configured.isEmpty || !FileManager.default.isExecutableFile(atPath: configured) ? login : configured
    }

    /// "zsh", "bash"…
    static func name(_ path: String) -> String { (path as NSString).lastPathComponent }

    /// Only zsh has the shell integration (smart input, command blocks) for now.
    static func hasIntegration(_ path: String) -> Bool { name(path) == "zsh" }
}
