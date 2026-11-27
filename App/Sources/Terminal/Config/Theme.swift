import AppKit

/// Colours, fonts and spacing for the app's own chrome (tab bar, prompt line,
/// input box, menus). Colours come from the terminal theme so everything matches.
struct Theme {
    var background: NSColor
    var foreground: NSColor
    var dim: NSColor
    var accent: NSColor
    var error: NSColor
    var success: NSColor
    var separator: NSColor
    var tabActive: NSColor
    var tabHover: NSColor
    var opacity: Double
    var font: NSFont
    var smallFont: NSFont

    // Spacing (specs/02-look.md): matches the terminal's window padding.
    static let paddingX: CGFloat = 16
    static let paddingY: CGFloat = 12
    static let tabBarHeight: CGFloat = 38
    static let tabHeight: CGFloat = 26
    static let tabCorner: CGFloat = 7
    static let menuCorner: CGFloat = 10
    static let trafficLightsInset: CGFloat = 80
    // Tab sidebar (specs/02-look.md)
    static let sidebarCardHeight: CGFloat = 44
    static let sidebarRowHeight: CGFloat = 30
    static let sidebarMargin: CGFloat = 8
    static let gearSize: CGFloat = 26

    static var current = Theme.make()

    static func make() -> Theme {
        let c = TerminalEngine.shared.colors
        let fontFamily = ConfigStore.shared.config.ghosttyLines
            .compactMap { line -> String? in
                let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                return parts.count == 2 && parts[0] == "font-family" ? parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"")) : nil
            }.last
        let size = CGFloat(ConfigStore.shared.fontSize)
        let font = fontFamily.flatMap { NSFont(name: $0, size: size) }
            ?? NSFont(name: "JetBrains Mono", size: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        let dark = c.background.brightness < 0.5
        return Theme(
            background: c.background,
            foreground: c.foreground,
            dim: c.foreground.withAlphaComponent(0.5),
            accent: TerminalEngine.shared.paletteColor(4) ?? .systemBlue,
            error: TerminalEngine.shared.paletteColor(1) ?? .systemRed,
            success: TerminalEngine.shared.paletteColor(2) ?? .systemGreen,
            separator: c.foreground.withAlphaComponent(dark ? 0.08 : 0.12),
            tabActive: c.foreground.withAlphaComponent(dark ? 0.10 : 0.09),
            tabHover: c.foreground.withAlphaComponent(dark ? 0.05 : 0.05),
            opacity: c.opacity,
            font: font,
            smallFont: NSFont.monospacedSystemFont(ofSize: max(size - 2, 10), weight: .regular)
        )
    }

    /// Background for chrome drawn over the translucent window.
    var chromeBackground: NSColor { background.withAlphaComponent(opacity) }
}

extension NSColor {
    var brightness: CGFloat {
        guard let c = usingColorSpace(.sRGB) else { return 0 }
        return 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent
    }
}

/// Holds the loaded config and tells the app when it changes.
final class ConfigStore {
    static let shared = ConfigStore()
    private(set) var config = AppConfig()
    private var watcher: ConfigWatcher?
    var onReload: (() -> Void)?

    /// Font size from the config, before zoom.
    var baseFontSize: Double {
        for line in config.ghosttyLines.reversed() {
            let p = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if p.count == 2, p[0] == "font-size", let v = Double(p[1]) { return v }
        }
        return AppConfig.defaultFontSize
    }

    /// Zoom (⌘+ / ⌘− / ⌘0) in points, for every window and the app's own chrome.
    /// Not saved: each launch starts at the configured size.
    private(set) var zoom: Double = 0
    static let zoomRange: ClosedRange<Double> = 8...36

    var fontSize: Double { min(max(baseFontSize + zoom, Self.zoomRange.lowerBound), Self.zoomRange.upperBound) }

    /// Each surface applies the size itself (libghostty's `set_font_size`):
    /// no config reload, so zooming costs one font grid per surface.
    func zoom(by step: Double) {
        zoom = step == 0 ? 0 : min(max(baseFontSize + zoom + step, Self.zoomRange.lowerBound), Self.zoomRange.upperBound) - baseFontSize
        applyFontSize()
    }

    private func applyFontSize() {
        Theme.current = Theme.make()
        NotificationCenter.default.post(name: .terminalFontSizeChanged, object: nil)
        NotificationCenter.default.post(name: .terminalThemeChanged, object: nil)
    }

    func load() {
        AppConfig.writeStarterIfMissing()
        config = AppConfig.load()
        watcher = ConfigWatcher { [weak self] in self?.reload() }
    }

    /// Dark or light, following the system appearance.
    private(set) var dark = false

    var ghosttyConfigText: String { config.ghosttyConfigText(dark: dark) }

    private func reload() {
        config = AppConfig.load()
        TerminalEngine.shared.reload(configText: ghosttyConfigText)
        // Surfaces keep the size they were given: send the configured one again.
        applyFontSize()
        onReload?()
    }

    /// Re-applies the config when the system switches between light and dark.
    /// Returns false when nothing changed.
    @discardableResult
    func setDark(_ dark: Bool) -> Bool {
        guard dark != self.dark else { return false }
        self.dark = dark
        if TerminalEngine.shared.app != nil {
            TerminalEngine.shared.reload(configText: ghosttyConfigText)
            Theme.current = Theme.make()
        }
        return true
    }
}
