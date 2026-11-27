import AppKit

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
