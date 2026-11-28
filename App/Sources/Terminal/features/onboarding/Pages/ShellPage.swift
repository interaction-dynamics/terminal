import AppKit

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
