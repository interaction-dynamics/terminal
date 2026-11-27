import AppKit

/// Anything that shows a `TerminalContentController` (normal window or hotkey dropdown).
protocol TerminalWindowController: AnyObject {
    var content: TerminalContentController { get }
    var window: NSWindow? { get }
}

// MARK: - Normal window (⌘N)

final class NormalWindowController: NSWindowController, NSWindowDelegate, TerminalWindowController {
    let content = TerminalContentController(leadingInset: Theme.trafficLightsInset)
    var onClose: ((NormalWindowController) -> Void)?

    init(cwd: String? = nil) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = false
        window.tabbingMode = .disallowed
        window.minSize = NSSize(width: 420, height: 240)
        window.contentView = content.root
        window.setFrameAutosaveName("TerminalWindow")
        super.init(window: window)
        window.delegate = self
        if window.frame.origin == .zero { window.center() }
        content.onEmpty = { [weak self] in self?.window?.close() }
        content.onTitleChange = { [weak window] t in window?.title = t }
        content.newTab(cwd: cwd)
        positionTrafficLights()
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        if let window { TerminalEngine.shared.applyBlur(to: window) }
        content.focusActive()
    }

    /// Centre the traffic lights vertically in the taller tab bar.
    private func positionTrafficLights() {
        guard let window else { return }
        for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            guard let b = window.standardWindowButton(type), let sup = b.superview else { continue }
            let y = sup.bounds.height - Theme.tabBarHeight / 2 - b.frame.height / 2
            b.setFrameOrigin(NSPoint(x: b.frame.origin.x + 6, y: y))
        }
    }

    func windowDidResize(_ notification: Notification) { positionTrafficLights() }
    func windowDidBecomeKey(_ notification: Notification) { content.focusActive() }

    func windowDidChangeOcclusionState(_ notification: Notification) {
        guard let window else { return }
        content.setOccluded(!window.occlusionState.contains(.visible))
    }

    func windowWillClose(_ notification: Notification) {
        for s in content.sessions { s.surface.close() }
        onClose?(self)
    }
}
