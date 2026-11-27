import AppKit

/// First-launch onboarding (specs/11-onboarding.md): a borderless, rounded
/// window with one page per step, the progress at the bottom left and the
/// buttons at the bottom right. Also opened from the menu button.
/// Choices are written to the config file as they are made.
final class Onboarding: NSObject, NSWindowDelegate {
    static let shared = Onboarding()

    private var window: OnboardingWindow?
    private var page = 0
    private var pageView: NSView?
    private var onDone: (() -> Void)?
    private let container = FlippedView()
    private let progress = OnboardingProgress(steps: OnboardingTuning.steps)
    private let back = NSButton(title: "Back", target: nil, action: nil)
    private let next = NSButton(title: "", target: nil, action: nil)

    func show(onDone: @escaping () -> Void) {
        self.onDone = onDone
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let w = makeWindow()
        window = w
        page = 0
        showPage(0, forward: true, animated: false)
        w.center()
        w.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            w.animator().alphaValue = 1
        }
    }

    // MARK: Window

    private func makeWindow() -> OnboardingWindow {
        let size = OnboardingTuning.size
        let w = OnboardingWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = true
        w.isMovableByWindowBackground = true
        w.isReleasedWhenClosed = false
        w.appearance = NSAppearance(named: .darkAqua)
        w.delegate = self
        w.onCancel = { [weak self] in self?.finish() }

        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = OnboardingTuning.cornerRadius
        background.layer?.masksToBounds = true
        background.layer?.borderWidth = 1
        background.layer?.borderColor = NSColor.white.withAlphaComponent(0.1).cgColor
        w.contentView = background
        // A dark tint over the blur, so it reads the same over any wallpaper.
        let tint = NSView(frame: background.bounds)
        tint.wantsLayer = true
        tint.layer?.backgroundColor = OnboardingTuning.tint.cgColor
        background.addSubview(tint)

        let footerH = OnboardingTuning.footerHeight
        container.frame = NSRect(x: 0, y: footerH, width: size.width, height: size.height - footerH)
        container.wantsLayer = true
        container.layer?.masksToBounds = true
        background.addSubview(container)

        let line = NSBox(frame: NSRect(x: 0, y: footerH, width: size.width, height: 1))
        line.boxType = .custom
        line.borderWidth = 0
        line.fillColor = NSColor.white.withAlphaComponent(0.08)
        background.addSubview(line)

        progress.frame = NSRect(x: 28, y: (footerH - 16) / 2, width: 220, height: 16)
        background.addSubview(progress)

        next.bezelStyle = .rounded
        next.keyEquivalent = "\r"
        next.target = self
        next.action = #selector(goNext)
        next.controlSize = .large
        back.bezelStyle = .rounded
        back.target = self
        back.action = #selector(goBack)
        back.controlSize = .large
        for b in [back, next] { background.addSubview(b) }
        return w
    }

    private func layoutButtons() {
        let footerH = OnboardingTuning.footerHeight
        let width = OnboardingTuning.size.width
        next.sizeToFit()
        back.sizeToFit()
        let nw = max(next.frame.width + 16, 110)
        next.frame = NSRect(x: width - 28 - nw, y: (footerH - next.frame.height) / 2, width: nw, height: next.frame.height)
        back.frame = NSRect(x: next.frame.minX - back.frame.width - 16 - 8, y: next.frame.minY, width: back.frame.width + 16, height: back.frame.height)
    }

    // MARK: Pages

    private func makePage(_ index: Int) -> NSView {
        let frame = container.bounds
        switch index {
        case 0: return WelcomePage(frame: frame)
        case 1: return ThemePage(frame: frame)
        case 2: return ShellPage(frame: frame)
        case 3: return HotkeyPage(frame: frame)
        default: return DonePage(frame: frame)
        }
    }

    private func showPage(_ index: Int, forward: Bool, animated: Bool) {
        page = index
        let old = pageView
        let new = makePage(index)
        new.wantsLayer = true
        container.addSubview(new)
        pageView = new
        progress.setStep(index, animated: animated)
        let last = index == OnboardingTuning.steps - 1
        next.title = index == 0 ? "Get Started" : (last ? "Start Using \(AppInfo.displayName)" : "Continue")
        back.isHidden = index == 0 || last
        layoutButtons()

        guard animated, let old else {
            old?.removeFromSuperview()
            (new as? OnboardingPage)?.didAppear()
            return
        }
        // Slide and fade: the new page comes from the side we are going to.
        let shift: CGFloat = forward ? 60 : -60
        let target = container.bounds
        new.frame = target.offsetBy(dx: shift, dy: 0)
        new.alphaValue = 0
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
            ctx.allowsImplicitAnimation = true
            new.animator().frame = target
            new.animator().alphaValue = 1
            old.animator().frame = target.offsetBy(dx: -shift, dy: 0)
            old.animator().alphaValue = 0
        }, completionHandler: {
            old.removeFromSuperview()
        })
        (new as? OnboardingPage)?.didAppear()
    }

    @objc private func goNext() {
        if page >= OnboardingTuning.steps - 1 { finish(); return }
        showPage(page + 1, forward: true, animated: true)
    }

    @objc private func goBack() {
        guard page > 0 else { return }
        showPage(page - 1, forward: false, animated: true)
    }

    private func finish() {
        guard let w = window else { return }
        onDone?()
        onDone = nil
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            w.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            w.orderOut(nil)
            self?.pageView?.removeFromSuperview()
            self?.pageView = nil
            self?.window = nil
        })
    }
}

/// Sizes and timings. Tune here.
enum OnboardingTuning {
    static let size = NSSize(width: 760, height: 500)
    static let footerHeight: CGFloat = 64
    static let cornerRadius: CGFloat = 16
    static let steps = 5
    static let pageInset: CGFloat = 56
    static let tint = NSColor(hex: "141419").withAlphaComponent(0.86)
}

final class OnboardingWindow: NSWindow {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}

/// The step bar at the bottom left: one segment per step, filled up to the current one.
final class OnboardingProgress: NSView {
    private var fills: [CALayer] = []
    private let label = NSTextField(labelWithString: "")
    private let steps: Int
    private static let segment = CGSize(width: 30, height: 4)

    init(steps: Int) {
        self.steps = steps
        super.init(frame: .zero)
        wantsLayer = true
        for i in 0..<steps {
            let track = CALayer()
            track.backgroundColor = NSColor.white.withAlphaComponent(0.15).cgColor
            track.cornerRadius = 2
            track.frame = NSRect(x: CGFloat(i) * (Self.segment.width + 6), y: 6, width: Self.segment.width, height: Self.segment.height)
            let fill = CALayer()
            fill.backgroundColor = NSColor.white.withAlphaComponent(0.9).cgColor
            fill.cornerRadius = 2
            fill.anchorPoint = .zero
            fill.frame = NSRect(x: 0, y: 0, width: 0, height: Self.segment.height)
            track.addSublayer(fill)
            layer?.addSublayer(track)
            fills.append(fill)
        }
        label.font = .systemFont(ofSize: 11.5)
        label.textColor = .secondaryLabelColor
        label.frame = NSRect(x: CGFloat(steps) * (Self.segment.width + 6) + 8, y: 0, width: 80, height: 16)
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setStep(_ step: Int, animated: Bool) {
        label.stringValue = "\(step + 1) of \(steps)"
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        CATransaction.setAnimationDuration(0.4)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        for (i, fill) in fills.enumerated() {
            fill.bounds.size.width = i <= step ? Self.segment.width : 0
        }
        CATransaction.commit()
    }
}
