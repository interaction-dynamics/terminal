import AppKit

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
