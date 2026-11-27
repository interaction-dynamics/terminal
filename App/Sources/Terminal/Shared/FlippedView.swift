import AppKit

/// A view with a top-left origin, for layouts written top to bottom
/// (the Settings tab and the onboarding pages).
class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
