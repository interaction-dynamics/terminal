import AppKit

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
