import AppKit

// MARK: - Hotkey dropdown (specs/03-hotkey-window.md)

final class HotkeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class HotkeyWindowController: NSObject, NSWindowDelegate, TerminalWindowController {
    let content = TerminalContentController(leadingInset: 12, compactChrome: true)
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
        // Clicking another app's window hides the dropdown; our own windows, menus and alerts don't.
        DispatchQueue.main.async { [self] in
            // A menu or popover of our own also takes key: only another app counts.
            if !NSApp.isActive {
                hide(restoreFocus: false)
            }
        }
    }

    func windowDidBecomeKey(_ notification: Notification) { content.focusActive() }
}
