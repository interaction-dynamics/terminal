import AppKit

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
