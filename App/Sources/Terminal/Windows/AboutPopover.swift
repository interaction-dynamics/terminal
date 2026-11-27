import AppKit

/// "About The Terminal": a small popover with the name and version, anchored
/// to the menu button.
final class AboutPopover: NSObject {
    static let shared = AboutPopover()
    private let popover = NSPopover()

    private override init() {
        super.init()
        popover.behavior = .transient
        popover.animates = true
    }

    func show(from view: NSView) {
        if popover.isShown { popover.performClose(nil); return }
        let vc = NSViewController()
        vc.view = makeView()
        popover.contentViewController = vc
        popover.contentSize = vc.view.fittingSize
        popover.appearance = NSAppearance(named: Theme.current.background.brightness < 0.5 ? .darkAqua : .aqua)
        popover.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }

    private func makeView() -> NSView {
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.widthAnchor.constraint(equalToConstant: 64).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 64).isActive = true
        let name = NSTextField(labelWithString: AppInfo.displayName)
        name.font = .systemFont(ofSize: 15, weight: .semibold)
        let tagline = NSTextField(labelWithString: AppInfo.tagline)
        tagline.font = .systemFont(ofSize: 12)
        tagline.textColor = .secondaryLabelColor
        let build = AppInfo.isReleaseBuild ? "" : " (local build)"
        let version = NSTextField(labelWithString: "Version \(AppInfo.version)\(build)")
        version.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        version.textColor = .secondaryLabelColor
        version.isSelectable = true
        let link = NSButton(title: "GitHub", target: self, action: #selector(openRepository))
        link.bezelStyle = .inline
        let stack = NSStackView(views: [icon, name, tagline, version, link])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        stack.setCustomSpacing(10, after: icon)
        stack.setCustomSpacing(12, after: version)
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 28, bottom: 18, right: 28)
        return stack
    }

    @objc private func openRepository() {
        popover.performClose(nil)
        NSWorkspace.shared.open(AppInfo.repositoryURL)
    }
}
