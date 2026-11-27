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

// MARK: - Page helpers

protocol OnboardingPage {
    /// Starts the page's entrance animation.
    func didAppear()
}

extension NSView {
    func onboardingLabel(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
        let l = NSTextField(wrappingLabelWithString: text)
        l.font = .systemFont(ofSize: size, weight: weight)
        l.textColor = color
        l.isSelectable = false
        return l
    }

    /// Fades the view in while it rises a little, after `delay` seconds.
    func riseIn(delay: CFTimeInterval, distance: CGFloat = 14) {
        guard let layer else { return }
        let now = CACurrentMediaTime()
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        let move = CABasicAnimation(keyPath: "transform.translation.y")
        move.fromValue = -distance   // layer y goes up; the views are flipped
        move.toValue = 0
        for a in [fade, move] {
            a.beginTime = now + delay
            a.duration = 0.5
            a.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
            a.fillMode = .backwards
            layer.add(a, forKey: a.keyPath)
        }
    }
}

// MARK: - 1. Welcome

final class WelcomePage: FlippedView, OnboardingPage {
    private let logo = AnimatedLogo(frame: NSRect(x: 0, y: 0, width: 84, height: 84))
    private var items: [NSView] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        let inset = OnboardingTuning.pageInset
        logo.frame.origin = NSPoint(x: inset, y: 44)
        addSubview(logo)

        let title = onboardingLabel("Welcome to \(AppInfo.displayName)", size: 30, weight: .bold)
        title.frame = NSRect(x: inset, y: 146, width: bounds.width - 2 * inset, height: 38)
        let subtitle = onboardingLabel(AppInfo.tagline, size: 16, color: .secondaryLabelColor)
        subtitle.frame = NSRect(x: inset, y: 188, width: bounds.width - 2 * inset, height: 22)
        addSubview(title)
        addSubview(subtitle)
        items = [logo, title, subtitle]

        let features: [(String, String, String)] = [
            ("lock.shield", "Confidential", "No account, no telemetry. What you type never leaves your Mac."),
            ("leaf", "Light", "Native and fast. Nothing runs in the background."),
            ("sparkles", "Aesthetic", "Calm colours, clean type, every detail considered."),
        ]
        let gap: CGFloat = 20
        let w = (bounds.width - 2 * inset - 2 * gap) / 3
        for (i, f) in features.enumerated() {
            let card = FeatureCard(symbol: f.0, title: f.1, text: f.2)
            card.frame = NSRect(x: inset + CGFloat(i) * (w + gap), y: 248, width: w, height: 120)
            addSubview(card)
            items.append(card)
        }
        for v in items { v.wantsLayer = true }
    }

    required init?(coder: NSCoder) { fatalError() }

    func didAppear() {
        for (i, v) in items.enumerated() { v.riseIn(delay: 0.08 * Double(i)) }
        logo.start()
    }
}

/// The welcome page's mark: a rounded tile with a prompt and a blinking
/// cursor, a slowly turning gradient and a soft glow.
final class AnimatedLogo: NSView {
    private let glow = CALayer()
    private let tile = CAGradientLayer()
    private let shine = CAGradientLayer()
    private let prompt = CATextLayer()
    private let cursor = CALayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        let b = bounds
        glow.frame = b.insetBy(dx: 6, dy: 6)
        glow.cornerRadius = 20
        glow.backgroundColor = NSColor.systemPurple.withAlphaComponent(0.5).cgColor
        glow.shadowColor = NSColor.systemPurple.cgColor
        glow.shadowRadius = 18
        glow.shadowOpacity = 0.8
        glow.shadowOffset = .zero
        layer?.addSublayer(glow)

        tile.frame = b
        tile.cornerRadius = 20
        tile.masksToBounds = true
        tile.colors = [NSColor(hex: "2b2d42").cgColor, NSColor(hex: "121218").cgColor]
        tile.startPoint = CGPoint(x: 0, y: 1)
        tile.endPoint = CGPoint(x: 1, y: 0)
        tile.borderWidth = 1
        tile.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
        layer?.addSublayer(tile)

        shine.type = .conic
        shine.frame = b.insetBy(dx: -b.width / 2, dy: -b.height / 2)
        shine.startPoint = CGPoint(x: 0.5, y: 0.5)
        shine.endPoint = CGPoint(x: 0.5, y: 0)
        shine.colors = [NSColor(hex: "7c6cff").withAlphaComponent(0.55).cgColor, NSColor.clear.cgColor,
                        NSColor(hex: "3ec7ff").withAlphaComponent(0.45).cgColor, NSColor.clear.cgColor,
                        NSColor(hex: "7c6cff").withAlphaComponent(0.55).cgColor]
        shine.opacity = 0.6
        tile.addSublayer(shine)

        prompt.string = "❯"
        prompt.font = NSFont.systemFont(ofSize: 30, weight: .bold)
        prompt.fontSize = 30
        prompt.foregroundColor = NSColor.white.cgColor
        prompt.alignmentMode = .left
        prompt.contentsScale = 2
        prompt.frame = NSRect(x: 18, y: 22, width: 30, height: 38)
        tile.addSublayer(prompt)

        cursor.backgroundColor = NSColor.white.withAlphaComponent(0.9).cgColor
        cursor.frame = NSRect(x: 46, y: 28, width: 16, height: 4)
        cursor.cornerRadius = 1.5
        tile.addSublayer(cursor)
    }

    required init?(coder: NSCoder) { fatalError() }

    func start() {
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = -2 * Double.pi
        spin.duration = 8
        spin.repeatCount = .infinity
        shine.add(spin, forKey: "spin")

        let blink = CAKeyframeAnimation(keyPath: "opacity")
        blink.values = [1, 1, 0, 0]
        blink.keyTimes = [0, 0.5, 0.5, 1]
        blink.duration = 1.1
        blink.repeatCount = .infinity
        cursor.add(blink, forKey: "blink")

        let pulse = CABasicAnimation(keyPath: "shadowRadius")
        pulse.fromValue = 12
        pulse.toValue = 26
        pulse.duration = 2.4
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        glow.add(pulse, forKey: "pulse")
    }
}

final class FeatureCard: FlippedView {
    init(symbol: String, title: String, text: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor

        let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
        icon.symbolConfiguration = .init(pointSize: 16, weight: .medium)
        icon.contentTintColor = NSColor(hex: "a99cff")
        icon.frame = NSRect(x: 14, y: 14, width: 22, height: 22)
        addSubview(icon)
        let t = onboardingLabel(title, size: 13.5, weight: .semibold)
        t.frame = NSRect(x: 14, y: 44, width: 180, height: 18)
        addSubview(t)
        let d = onboardingLabel(text, size: 12, color: .secondaryLabelColor)
        d.frame = NSRect(x: 14, y: 66, width: 180, height: 46)
        addSubview(d)
    }

    override func layout() {
        super.layout()
        for v in subviews where v is NSTextField { v.frame.size.width = bounds.width - 28 }
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - 2. Theme

final class ThemePage: FlippedView, OnboardingPage {
    private var items: [NSView] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        let inset = OnboardingTuning.pageInset
        let title = onboardingLabel("Choose your look", size: 26, weight: .bold)
        title.frame = NSRect(x: inset, y: 56, width: bounds.width - 2 * inset, height: 34)
        let subtitle = onboardingLabel("The whole app follows the theme. You can change it any time in Settings.", size: 14, color: .secondaryLabelColor)
        subtitle.frame = NSRect(x: inset, y: 96, width: bounds.width - 2 * inset, height: 20)
        let picker = ThemePickerView()
        picker.textColor = .white
        picker.selected = ConfigStore.shared.config.theme
        picker.onPick = { AppConfig.update("theme", to: $0) }
        picker.frame = NSRect(x: inset, y: 168, width: bounds.width - 2 * inset, height: 110)
        let hint = onboardingLabel("Your terminal windows change as you pick.", size: 12, color: .tertiaryLabelColor)
        hint.frame = NSRect(x: inset, y: 316, width: bounds.width - 2 * inset, height: 16)
        items = [title, subtitle, picker, hint]
        for v in items { v.wantsLayer = true; addSubview(v) }
    }

    required init?(coder: NSCoder) { fatalError() }

    func didAppear() {
        for (i, v) in items.enumerated() { v.riseIn(delay: 0.06 * Double(i)) }
    }
}

// MARK: - 3. Shell

final class ShellPage: FlippedView, OnboardingPage {
    private var items: [NSView] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        let inset = OnboardingTuning.pageInset
        let title = onboardingLabel("Your shell", size: 26, weight: .bold)
        title.frame = NSRect(x: inset, y: 56, width: bounds.width - 2 * inset, height: 34)
        let subtitle = onboardingLabel("New tabs start with this shell. Smart input and command blocks work with zsh for now.",
                                       size: 14, color: .secondaryLabelColor)
        subtitle.frame = NSRect(x: inset, y: 96, width: bounds.width - 2 * inset - 40, height: 40)
        let picker = ShellPickerView(shells: Shells.available())
        picker.selected = Shells.resolved(ConfigStore.shared.config.shell)
        picker.onPick = { Shells.choose($0) }
        picker.frame = NSRect(x: inset, y: 158, width: bounds.width - 2 * inset, height: min(picker.preferredHeight, 200))
        items = [title, subtitle, picker]
        for v in items { v.wantsLayer = true; addSubview(v) }
    }

    required init?(coder: NSCoder) { fatalError() }

    func didAppear() {
        for (i, v) in items.enumerated() { v.riseIn(delay: 0.06 * Double(i)) }
    }
}

// MARK: - 4. Hotkey window

final class HotkeyPage: FlippedView, OnboardingPage {
    private var items: [NSView] = []
    private let enabled = NSSwitch()
    private let recorder = ShortcutRecorder()
    private var position: NSSegmentedControl!
    private let hideOnBlur = NSSwitch()
    private let preview = ScreenPositionPreview(frame: NSRect(x: 0, y: 0, width: 200, height: 128))

    override init(frame: NSRect) {
        super.init(frame: frame)
        let inset = OnboardingTuning.pageInset
        let config = ConfigStore.shared.config
        let title = onboardingLabel("The hotkey window", size: 26, weight: .bold)
        title.frame = NSRect(x: inset, y: 56, width: bounds.width - 2 * inset, height: 34)
        let subtitle = onboardingLabel("A terminal that drops down over any app with one shortcut, and goes away with the same one.",
                                       size: 14, color: .secondaryLabelColor)
        subtitle.frame = NSRect(x: inset, y: 96, width: bounds.width - 2 * inset - 40, height: 40)

        let labelX = inset, controlX = inset + 120
        func label(_ text: String, y: CGFloat) -> NSTextField {
            let l = onboardingLabel(text, size: 13, color: .secondaryLabelColor)
            l.frame = NSRect(x: labelX, y: y, width: 110, height: 18)
            return l
        }
        enabled.state = config.hotkeyEnabled ? .on : .off
        enabled.target = self
        enabled.action = #selector(enabledChanged)
        enabled.frame = NSRect(x: controlX, y: 174, width: 40, height: 22)
        recorder.spec = config.hotkey
        recorder.isEnabled = config.hotkeyEnabled
        recorder.onChange = { AppConfig.update("hotkey", to: $0) }
        recorder.frame = NSRect(x: controlX, y: 218, width: 170, height: 26)
        position = HotkeyPositions.makeControl(target: self, action: #selector(positionChanged))
        position.selectedSegment = HotkeyPositions.all.firstIndex(of: config.hotkeyPosition) ?? 0
        position.isEnabled = config.hotkeyEnabled
        position.sizeToFit()
        position.frame.origin = NSPoint(x: controlX, y: 266)
        hideOnBlur.state = config.hotkeyAutohide ? .on : .off
        hideOnBlur.isEnabled = config.hotkeyEnabled
        hideOnBlur.target = self
        hideOnBlur.action = #selector(hideOnBlurChanged)
        hideOnBlur.frame = NSRect(x: controlX, y: 310, width: 40, height: 22)
        preview.position = config.hotkeyPosition
        preview.frame.origin = NSPoint(x: bounds.width - inset - 200, y: 170)
        preview.alphaValue = config.hotkeyEnabled ? 1 : 0.4

        items = [title, subtitle, label("Hotkey window", y: 176), enabled, label("Shortcut", y: 222), recorder,
                 label("Position", y: 269), position, label("Hide on blur", y: 312), hideOnBlur, preview]
        for v in items { v.wantsLayer = true; addSubview(v) }
    }

    required init?(coder: NSCoder) { fatalError() }

    func didAppear() {
        for (i, v) in items.enumerated() { v.riseIn(delay: 0.04 * Double(i)) }
    }

    @objc private func enabledChanged() {
        let on = enabled.state == .on
        recorder.isEnabled = on
        position.isEnabled = on
        hideOnBlur.isEnabled = on
        preview.animator().alphaValue = on ? 1 : 0.4
        AppConfig.update("hotkey-enabled", to: on ? "true" : "false")
    }

    @objc private func hideOnBlurChanged() {
        AppConfig.update("hotkey-autohide", to: hideOnBlur.state == .on ? "true" : "false")
    }

    @objc private func positionChanged() {
        let edge = HotkeyPositions.all[position.selectedSegment]
        preview.position = edge
        AppConfig.update("hotkey-position", to: edge.rawValue)
    }
}

// MARK: - 5. Done

final class DonePage: FlippedView, OnboardingPage {
    private var items: [NSView] = []
    private let check = CheckmarkView(frame: NSRect(x: 0, y: 0, width: 76, height: 76))

    override init(frame: NSRect) {
        super.init(frame: frame)
        let inset = OnboardingTuning.pageInset
        check.frame.origin = NSPoint(x: (bounds.width - 76) / 2, y: 64)
        let title = onboardingLabel("Congratulations!", size: 30, weight: .bold)
        title.alignment = .center
        title.frame = NSRect(x: inset, y: 166, width: bounds.width - 2 * inset, height: 38)
        let subtitle = onboardingLabel("You're all set. Feel free to give your feedback: it shapes what comes next.",
                                       size: 15, color: .secondaryLabelColor)
        subtitle.alignment = .center
        subtitle.frame = NSRect(x: inset + 40, y: 212, width: bounds.width - 2 * inset - 80, height: 44)
        let link = NSButton(title: "Give feedback on GitHub", target: self, action: #selector(openFeedback))
        link.bezelStyle = .rounded
        link.controlSize = .large
        link.image = NSImage(systemSymbolName: "arrow.up.right", accessibilityDescription: nil)
        link.imagePosition = .imageTrailing
        link.sizeToFit()
        link.frame = NSRect(x: (bounds.width - link.frame.width - 24) / 2, y: 276, width: link.frame.width + 24, height: link.frame.height)
        items = [check, title, subtitle, link]
        for v in items { v.wantsLayer = true; addSubview(v) }
    }

    required init?(coder: NSCoder) { fatalError() }

    func didAppear() {
        for (i, v) in items.enumerated() where i > 0 { v.riseIn(delay: 0.25 + 0.07 * Double(i)) }
        check.start()
    }

    @objc private func openFeedback() { NSWorkspace.shared.open(AppInfo.feedbackURL) }
}

/// A circle that pops in and a check that draws itself, with a small burst
/// of sparks.
final class CheckmarkView: NSView {
    private let circle = CAShapeLayer()
    private let mark = CAShapeLayer()
    private let sparks = CAEmitterLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        let b = bounds
        circle.frame = b
        circle.path = CGPath(ellipseIn: b.insetBy(dx: 3, dy: 3), transform: nil)
        circle.fillColor = NSColor.systemGreen.withAlphaComponent(0.18).cgColor
        circle.strokeColor = NSColor.systemGreen.cgColor
        circle.lineWidth = 3
        layer?.addSublayer(circle)

        let p = CGMutablePath()
        p.move(to: CGPoint(x: b.width * 0.30, y: b.height * 0.50))
        p.addLine(to: CGPoint(x: b.width * 0.44, y: b.height * 0.36))
        p.addLine(to: CGPoint(x: b.width * 0.70, y: b.height * 0.64))
        mark.path = p
        mark.fillColor = nil
        mark.strokeColor = NSColor.white.cgColor
        mark.lineWidth = 5
        mark.lineCap = .round
        mark.lineJoin = .round
        mark.strokeEnd = 0
        layer?.addSublayer(mark)

        sparks.emitterPosition = CGPoint(x: b.midX, y: b.midY)
        sparks.emitterShape = .circle
        sparks.emitterSize = CGSize(width: b.width * 0.8, height: b.height * 0.8)
        sparks.birthRate = 0
        let cell = CAEmitterCell()
        cell.contents = Self.dot()
        cell.birthRate = 160
        cell.lifetime = 1.1
        cell.velocity = 120
        cell.velocityRange = 60
        cell.emissionRange = .pi * 2
        cell.scale = 0.5
        cell.scaleRange = 0.3
        cell.alphaSpeed = -1
        cell.color = NSColor(hex: "a99cff").cgColor
        cell.redRange = 0.4
        cell.greenRange = 0.4
        cell.blueRange = 0.2
        sparks.emitterCells = [cell]
        layer?.addSublayer(sparks)
        layer?.masksToBounds = false
    }

    required init?(coder: NSCoder) { fatalError() }

    private static func dot() -> CGImage? {
        let img = NSImage(size: NSSize(width: 8, height: 8), flipped: false) { r in
            NSColor.white.setFill()
            NSBezierPath(ovalIn: r).fill()
            return true
        }
        return img.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    func start() {
        let pop = CASpringAnimation(keyPath: "transform.scale")
        pop.fromValue = 0.3
        pop.toValue = 1
        pop.damping = 9
        pop.initialVelocity = 6
        pop.duration = pop.settlingDuration
        circle.add(pop, forKey: "pop")

        let draw = CABasicAnimation(keyPath: "strokeEnd")
        draw.fromValue = 0
        draw.toValue = 1
        draw.beginTime = CACurrentMediaTime() + 0.25
        draw.duration = 0.4
        draw.timingFunction = CAMediaTimingFunction(name: .easeOut)
        draw.fillMode = .backwards
        mark.strokeEnd = 1
        mark.add(draw, forKey: "draw")

        sparks.beginTime = CACurrentMediaTime()
        sparks.birthRate = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in self?.sparks.birthRate = 0 }
    }
}
