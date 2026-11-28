import AppKit

/// Names and links shown in the app (menu, About, onboarding). One place to change them.
enum AppInfo {
    static let displayName = "The Terminal"
    static let tagline = "The ultimate terminal for macOS."
    static let repositoryURL = URL(string: "https://github.com/\(UpdateTuning.repository)")!
    /// "Send Feedback" and the last onboarding page open this.
    static let feedbackURL = URL(string: "https://github.com/\(UpdateTuning.repository)/issues")!

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    static var isReleaseBuild: Bool {
        Bundle.main.infoDictionary?["TerminalReleaseBuild"] as? Bool == true
    }
}

extension Notification.Name {
    /// Posted with `true` while a shortcut recorder listens, `false` after:
    /// the global hotkey steps aside so it can be recorded.
    static let terminalRecordingShortcut = Notification.Name("terminalRecordingShortcut")
}
