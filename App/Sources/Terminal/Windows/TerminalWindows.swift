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

// MARK: - Hotkey dropdown (specs/03-hotkey-window.md)

final class HotkeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class HotkeyWindowController: NSObject, NSWindowDelegate, TerminalWindowController {
    let content = TerminalContentController(leadingInset: 12)
    let panel: HotkeyPanel
    var window: NSWindow? { panel }
    private(set) var isShown = false
    private var previousApp: NSRunningApplication?
    private var animating = false

    override init() {
        panel = HotkeyPanel(contentRect: NSRect(x: 0, y: 0, width: 800, height: 400),
                            styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
        super.init()
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.contentView = content.root
        content.root.wantsLayer = true
        content.root.layer?.masksToBounds = true
        panel.delegate = self
        content.onEmpty = { [weak self] in
            // Never destroy the dropdown: start a fresh shell and hide.
            self?.content.newTab()
            self?.hide()
        }
        // Created once at launch, with its shell already running, so showing is instant.
        content.newTab()
        content.setOccluded(true)
    }

    func toggle() { isShown ? hide() : show() }

    private var config: AppConfig { ConfigStore.shared.config }

    private func targetScreen() -> NSScreen {
        if config.hotkeyScreen == .mouse {
            let p = NSEvent.mouseLocation
            if let s = NSScreen.screens.first(where: { NSMouseInRect(p, $0.frame, false) }) { return s }
        }
        return NSScreen.main ?? NSScreen.screens[0]
    }

    /// Final frame and the off-screen frame it slides in from.
    private func frames(on screen: NSScreen) -> (NSRect, NSRect) {
        let vis = screen.visibleFrame
        let full = screen.frame
        let w = config.hotkeyWidth.resolve(in: vis.width)
        let h = config.hotkeyHeight.resolve(in: vis.height)
        var target: NSRect
        var start: NSRect
        switch config.hotkeyPosition {
        case .top:
            target = NSRect(x: vis.midX - w / 2, y: vis.maxY - h, width: w, height: h)
            start = target.offsetBy(dx: 0, dy: h)
        case .bottom:
            target = NSRect(x: vis.midX - w / 2, y: vis.minY, width: w, height: h)
            start = target.offsetBy(dx: 0, dy: -h)
        case .left:
            let lw = config.hotkeyWidth == .percent(1) ? vis.width * 0.4 : w
            let lh = config.hotkeyHeight == .percent(0.45) ? vis.height : h
            target = NSRect(x: vis.minX, y: vis.midY - lh / 2, width: lw, height: lh)
            start = target.offsetBy(dx: -lw, dy: 0)
        case .right:
            let lw = config.hotkeyWidth == .percent(1) ? vis.width * 0.4 : w
            let lh = config.hotkeyHeight == .percent(0.45) ? vis.height : h
            target = NSRect(x: vis.maxX - lw, y: vis.midY - lh / 2, width: lw, height: lh)
            start = target.offsetBy(dx: lw, dy: 0)
        case .center:
            let cw = config.hotkeyWidth == .percent(1) ? vis.width * 0.7 : w
            let ch = config.hotkeyHeight == .percent(0.45) ? vis.height * 0.6 : h
            target = NSRect(x: vis.midX - cw / 2, y: vis.midY - ch / 2, width: cw, height: ch)
            start = target
        }
        _ = full
        return (target, start)
    }

    private func applyCorners() {
        guard let layer = content.root.layer else { return }
        layer.cornerRadius = 12
        switch config.hotkeyPosition {
        case .top: layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]   // bottom corners
        case .bottom: layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        case .left: layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        case .right: layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        case .center: layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        }
    }

    func show() {
        guard !isShown else { return }
        isShown = true
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier { previousApp = front }

        let (target, start) = frames(on: targetScreen())
        applyCorners()
        let duration = config.hotkeyAnimation
        panel.setFrame(duration > 0 ? start : target, display: false)
        content.setOccluded(false)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        TerminalEngine.shared.applyBlur(to: panel)
        content.focusActive()
        if duration > 0, start != target {
            animating = true
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = duration
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(target, display: true)
            }, completionHandler: { [weak self] in self?.animating = false })
        }
    }

    func hide(restoreFocus: Bool = true) {
        guard isShown else { return }
        isShown = false
        let duration = config.hotkeyAnimation
        let (_, start) = frames(on: panel.screen ?? targetScreen())
        let finish = { [weak self] in
            guard let self else { return }
            self.panel.orderOut(nil)
            self.content.setOccluded(true)
            if restoreFocus, let app = self.previousApp {
                app.activate()
            } else if restoreFocus, NSApp.windows.allSatisfy({ !$0.isVisible || $0 === self.panel }) {
                NSApp.hide(nil)
            }
            self.previousApp = nil
        }
        if duration > 0, config.hotkeyPosition != .center {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = duration
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().setFrame(start, display: true)
            }, completionHandler: finish)
        } else {
            finish()
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        guard config.hotkeyAutohide, isShown, !animating else { return }
        // Clicking another app's window hides the dropdown; our own windows/alerts don't.
        DispatchQueue.main.async { [self] in
            if NSApp.keyWindow == nil || !NSApp.isActive {
                hide(restoreFocus: false)
            }
        }
    }

    func windowDidBecomeKey(_ notification: Notification) { content.focusActive() }
}
