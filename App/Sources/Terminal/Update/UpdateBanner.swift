import AppKit

/// Thin bar at the top of the terminal area when a new version is out
/// (specs/10-updates.md): icon and message on the left, text buttons and a
/// close button on the right. Follows `Updater.shared.state`.
final class UpdateBanner: NSView {
    /// Look of the banner. Tune here.
    enum Tuning {
        static let height: CGFloat = 32
        static let paddingX: CGFloat = 14
        static let buttonSpacing: CGFloat = 16
        static let fontSize: CGFloat = 12
    }

    private let icon = NSImageView()
    private let message = NSTextField(labelWithString: "")
    private let notes = UpdateBanner.textButton("Release Notes", #selector(Updater.openReleaseNotes(_:)))
    private let install = UpdateBanner.textButton("Install and Relaunch", #selector(Updater.installAvailable(_:)))
    private let skip = UpdateBanner.textButton("Skip This Version", #selector(Updater.skipAvailable(_:)))
    private let close = NSButton()

    /// Called when the banner appears or goes, so the window lays out again.
    var onVisibilityChange: (() -> Void)?

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        icon.imageScaling = .scaleProportionallyDown
        message.font = .systemFont(ofSize: Tuning.fontSize)
        message.lineBreakMode = .byTruncatingTail
        message.cell?.truncatesLastVisibleLine = true
        close.isBordered = false
        close.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")?
            .withSymbolConfiguration(.init(pointSize: 11, weight: .semibold))
        close.imagePosition = .imageOnly
        close.target = Updater.shared
        close.action = #selector(Updater.dismissAvailable(_:))
        close.toolTip = "Hide until the next check"
        for v in [icon, message, notes, install, skip, close] as [NSView] { addSubview(v) }
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged), name: .terminalUpdateState, object: nil)
        update()
    }

    required init?(coder: NSCoder) { fatalError() }

    private static func textButton(_ title: String, _ action: Selector) -> NSButton {
        let b = NSButton(title: title, target: Updater.shared, action: action)
        b.isBordered = false
        b.font = .systemFont(ofSize: Tuning.fontSize)
        return b
    }

    @objc private func stateChanged() {
        let wasHidden = isHidden
        update()
        if isHidden != wasHidden { onVisibilityChange?() }
    }

    private func update() {
        let name = AppInfo.displayName
        switch Updater.shared.state {
        case .none:
            isHidden = true
        case .available(let release):
            isHidden = false
            message.stringValue = "\(name) \(release.version) is available. You have \(Updater.shared.currentVersion)."
            for b in [notes, install, skip, close] { b.isHidden = false }
        case .installing(let release):
            isHidden = false
            message.stringValue = "Downloading \(name) \(release.version)… The app relaunches when it is ready."
            for b in [notes, install, skip, close] { b.isHidden = true }
        }
        applyTheme()
        needsLayout = true
    }

    func applyTheme() {
        let theme = Theme.current
        let symbol = { if case .installing = Updater.shared.state { return "arrow.down.circle" }; return "sparkles" }()
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .medium))
        icon.contentTintColor = theme.accent
        message.textColor = theme.foreground.withAlphaComponent(0.9)
        for (b, strong) in [(notes, false), (install, true), (skip, false)] {
            b.attributedTitle = NSAttributedString(string: b.title, attributes: [
                .font: NSFont.systemFont(ofSize: Tuning.fontSize, weight: strong ? .medium : .regular),
                .foregroundColor: strong ? theme.accent : theme.foreground.withAlphaComponent(0.65),
            ])
        }
        close.contentTintColor = theme.foreground.withAlphaComponent(0.7)
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        let h = bounds.height
        var right = bounds.width - Tuning.paddingX
        if !close.isHidden {
            close.frame = NSRect(x: right - 16, y: (h - 16) / 2, width: 16, height: 16)
            right = close.frame.minX - Tuning.buttonSpacing
        }
        // Right to left: the most important button sits nearest the close button.
        for b in [skip, install, notes] where !b.isHidden {
            let w = ceil(b.attributedTitle.size().width) + 4
            b.frame = NSRect(x: right - w, y: (h - 18) / 2, width: w, height: 18)
            right = b.frame.minX - Tuning.buttonSpacing
        }
        icon.frame = NSRect(x: Tuning.paddingX, y: (h - 14) / 2, width: 14, height: 14)
        let x = icon.frame.maxX + 9
        let textH = ceil(message.intrinsicContentSize.height)
        message.frame = NSRect(x: x, y: (h - textH) / 2, width: max(0, right - x), height: textH)
    }

    override func draw(_ dirtyRect: NSRect) {
        let theme = Theme.current
        theme.chromeBackground.setFill()
        bounds.fill()
        theme.foreground.withAlphaComponent(0.05).setFill()
        bounds.fill(using: .sourceOver)
        theme.separator.setFill()
        NSRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1).fill(using: .sourceOver)
    }
}
