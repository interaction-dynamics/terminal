import AppKit

/// "About The Terminal": a small window with the icon, name, tagline,
/// version and a GitHub link, centred over the window it was opened from.
/// Closes with its close button, Esc or ⌘W.
final class AboutWindow: NSObject, NSWindowDelegate {
    static let shared = AboutWindow()

    /// Size and padding. Tune here.
    enum Tuning {
        static let width: CGFloat = 300
        static let padding = NSEdgeInsets(top: 36, left: 28, bottom: 24, right: 28)
        static let iconSize: CGFloat = 72
    }

    private var window: NSWindow?

    func show(over parent: NSWindow?) {
        let w = window ?? makeWindow()
        window = w
        w.appearance = NSAppearance(named: Theme.current.background.brightness < 0.5 ? .darkAqua : .aqua)
        let anchor = parent?.frame ?? NSScreen.main?.visibleFrame ?? .zero
        w.setFrameOrigin(NSPoint(x: anchor.midX - w.frame.width / 2, y: anchor.midY - w.frame.height / 2 + anchor.height * 0.1))
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let w = AboutPanel(contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView],
                           backing: .buffered, defer: false)
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isMovableByWindowBackground = true
        w.isReleasedWhenClosed = false
        // Above the hotkey dropdown (which floats), on whatever Space is active.
        w.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        w.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        w.delegate = self
        w.standardWindowButton(.miniaturizeButton)?.isHidden = true
        w.standardWindowButton(.zoomButton)?.isHidden = true

        let content = NSVisualEffectView()
        content.material = .popover
        content.blendingMode = .behindWindow
        content.state = .active
        let stack = makeStack()
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        let p = Tuning.padding
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: p.top),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -p.bottom),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: p.left),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -p.right),
            content.widthAnchor.constraint(equalToConstant: Tuning.width),
        ])
        w.contentView = content
        content.layoutSubtreeIfNeeded()
        w.setContentSize(content.fittingSize)
        return w
    }

    private func makeStack() -> NSStackView {
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.widthAnchor.constraint(equalToConstant: Tuning.iconSize).isActive = true
        icon.heightAnchor.constraint(equalToConstant: Tuning.iconSize).isActive = true
        let name = label(AppInfo.displayName, font: .systemFont(ofSize: 17, weight: .semibold), color: .labelColor)
        let tagline = label(AppInfo.tagline, font: .systemFont(ofSize: 12.5), color: .secondaryLabelColor)
        let build = AppInfo.isReleaseBuild ? "" : " (local build)"
        let version = label("Version \(AppInfo.version)\(build)", font: .monospacedDigitSystemFont(ofSize: 12, weight: .regular),
                            color: .tertiaryLabelColor)
        version.isSelectable = true
        let link = NSButton(title: "GitHub", target: self, action: #selector(openRepository))
        link.bezelStyle = .rounded
        link.image = NSImage(systemSymbolName: "arrow.up.right", accessibilityDescription: nil)
        link.imagePosition = .imageTrailing
        let stack = NSStackView(views: [icon, name, tagline, version, link])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 4
        stack.setCustomSpacing(14, after: icon)
        stack.setCustomSpacing(10, after: tagline)
        stack.setCustomSpacing(18, after: version)
        return stack
    }

    private func label(_ text: String, font: NSFont, color: NSColor) -> NSTextField {
        let l = NSTextField(wrappingLabelWithString: text)
        l.font = font
        l.textColor = color
        l.alignment = .center
        l.preferredMaxLayoutWidth = Tuning.width - Tuning.padding.left - Tuning.padding.right
        return l
    }

    @objc private func openRepository() {
        window?.close()
        NSWorkspace.shared.open(AppInfo.repositoryURL)
    }
}

/// Esc closes it, like a sheet.
private final class AboutPanel: NSWindow {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { close() }
}
