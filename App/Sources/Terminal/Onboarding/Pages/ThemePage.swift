import AppKit

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
