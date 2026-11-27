import AppKit

/// One tab: a shell, its terminal surface and the smart-input state (specs/04-smart-input.md).
final class Session: TerminalSurfaceDelegate {
    enum State: Equatable {
        /// Our shell integration is loading. The smart input is already shown so
        /// early typing lands there, not in the raw terminal.
        case starting
        /// No prompt mark seen (ssh, other shells, broken integration). Plain terminal.
        case noIntegration
        /// The shell waits for a command: the smart input is shown.
        case atPrompt
        /// A command runs: keys go to the program.
        case running
    }

    let id = UUID().uuidString
    let surface: TerminalSurface
    var onChange: ((Session) -> Void)?
    var onClose: ((Session) -> Void)?

    private(set) var state: State = .noIntegration
    private(set) var title = ""
    private(set) var cwd: String
    private(set) var gitRoot: String?
    private(set) var gitBranch: String?
    private(set) var lastExitCode: Int?
    private(set) var lastDurationMs: Int?
    private(set) var runningCommand: String?
    private(set) var previousCommand: String?
    private var lastHistoryID: Int64?
    private var commandStartedAt: Date?
    /// The shell reported the running command's exit code and duration.
    private var finishReported = false
    var draft = ""
    /// A command submitted before the first prompt: runs as soon as it appears.
    private(set) var pendingCommand: String?

    /// How long to wait for the first prompt before falling back to a plain terminal.
    static let startupTimeout: TimeInterval = 3
    /// A command shows as running (input box hidden, tab named after it) only
    /// once it has run this long, so quick commands don't make the window flash.
    static let runningRevealDelay: TimeInterval = 0.3
    /// The UI shows the command as running (see `runningRevealDelay`).
    private(set) var runningRevealed = false
    private var revealWork: DispatchWorkItem?

    init(workingDirectory: String?, smartInput: Bool) {
        let cwd = workingDirectory ?? FileManager.default.homeDirectoryForCurrentUser.path
        self.cwd = cwd
        var env: [String: String] = ["TERMINAL_SESSION_ID": id, "TERM_PROGRAM": "Terminal-libghostty"]
        let shell = Shells.resolved(ConfigStore.shared.config.shell)
        if let integration = Bundle.main.resourceURL?.appendingPathComponent("shell-integration/zsh"),
           FileManager.default.fileExists(atPath: integration.appendingPathComponent(".zshenv").path),
           Shells.hasIntegration(shell) {
            if let existing = ProcessInfo.processInfo.environment["ZDOTDIR"] { env["TERMINAL_ZSH_ZDOTDIR"] = existing }
            env["ZDOTDIR"] = integration.path
            env["TERMINAL_SMART_INPUT"] = smartInput ? "1" : "0"
            if smartInput { state = .starting }
        }
        Debug.log("[\(id)] new session env: \(env)")
        // The login shell runs as libghostty starts it (a login shell); another
        // one is started as a login shell too.
        let command = shell == Shells.login ? nil : "\(shell) -l"
        env["SHELL"] = shell
        // macOS's bash prints a "default shell is now zsh" notice: the user chose bash.
        if Shells.name(shell) == "bash" { env["BASH_SILENCE_DEPRECATION_WARNING"] = "1" }
        surface = TerminalSurfaceView(options: SurfaceOptions(workingDirectory: cwd, environment: env, command: command))
        surface.delegate = self
        refreshGit()
        if state == .starting {
            // One-shot, not polling: if the integration never reports a prompt
            // (a zshrc that breaks it), hand the keyboard to the terminal.
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.startupTimeout) { [weak self] in
                guard let self, self.state == .starting else { return }
                Debug.log("[\(self.id)] no prompt after \(Self.startupTimeout)s: plain terminal")
                self.state = .noIntegration
                if let pending = self.pendingCommand {
                    self.pendingCommand = nil
                    self.surface.sendText(pending)
                    self.surface.sendKey(.enter)
                }
                self.onChange?(self)
            }
        }
    }

    /// Whether the smart input takes the keyboard.
    var acceptsInput: Bool { state == .atPrompt || (state == .starting && pendingCommand == nil) }

    /// Whether the input box is on screen: when it takes the keyboard, and
    /// during the first moments of a command (the keys already go to it).
    var showsInput: Bool { acceptsInput || (state == .running && !runningRevealed) }


    /// Label for the tab: the running command, else the folder name
    /// ("Home" for ~, so a tab never reads as a lone "~").
    var label: String {
        if state == .running, runningRevealed, let cmd = runningCommand { return cmd }
        if !title.isEmpty, state == .noIntegration { return title }
        return cwd == NSHomeDirectory() ? "Home" : (cwd as NSString).lastPathComponent
    }

    var displayDirectory: String {
        let home = NSHomeDirectory()
        return cwd.hasPrefix(home) ? "~" + cwd.dropFirst(home.count) : cwd
    }

    var rankContext: RankContext {
        RankContext(cwd: cwd, gitRoot: gitRoot, previousCommand: previousCommand)
    }

    // MARK: Running commands from the smart input

    func submit(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        if state == .starting {
            // The shell isn't ready: keep it for the first prompt.
            pendingCommand = command
            onChange?(self)
            return
        }
        if trimmed.isEmpty {
            surface.sendKey(.enter)
            return
        }
        state = .running
        runningCommand = trimmed
        runningRevealed = false
        revealWork?.cancel()
        let reveal = DispatchWorkItem { [weak self] in
            guard let self, self.state == .running else { return }
            self.runningRevealed = true
            self.onChange?(self)
        }
        revealWork = reveal
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.runningRevealDelay, execute: reveal)
        commandStartedAt = Date()
        // The prompt line keeps the previous status until the new one arrives,
        // so it doesn't blink.
        finishReported = false
        let entry = HistoryEntry(
            command: trimmed, cwd: cwd, gitRoot: gitRoot, exitCode: nil,
            startedAt: Int64(Date().timeIntervalSince1970 * 1000), durationMs: nil,
            sessionID: id, prevID: lastHistoryID)
        HistoryStore.shared.record(entry) { [weak self] rowID in
            DispatchQueue.main.async { self?.lastHistoryID = rowID }
        }
        previousCommand = trimmed
        // Bracketed paste so the shell gets the text as one piece, then Enter.
        surface.sendText(command)
        surface.sendKey(.enter)
        onChange?(self)
    }

    /// Ctrl+D on an empty input.
    func sendEOF() { surface.sendKey(.endOfFile) }

    // MARK: TerminalSurfaceDelegate

    func surface(_ surface: TerminalSurface, didChangeTitle title: String) {
        Debug.log("[\(id)] title: \(title)")
        self.title = title
        onChange?(self)
    }

    func surface(_ surface: TerminalSurface, didReportDirectory path: String) {
        Debug.log("[\(id)] pwd: \(path) state: \(state)")
        // OSC 7 comes from our precmd hook: a prompt is ready.
        let wasRunning = state == .running
        if path != cwd || wasRunning {
            cwd = path
            refreshGit()
        }
        if wasRunning, let started = commandStartedAt, !finishReported {
            lastExitCode = nil
            lastDurationMs = Int(Date().timeIntervalSince(started) * 1000)
        }
        commandStartedAt = nil
        state = .atPrompt
        runningCommand = nil
        revealWork?.cancel()
        revealWork = nil
        runningRevealed = false
        onChange?(self)
        HistoryStore.shared.prepare(rankContext)
        if let pending = pendingCommand {
            pendingCommand = nil
            submit(pending)
        }
    }

    func surface(_ surface: TerminalSurface, didFinishCommandWithExitCode code: Int?, durationMs: Int) {
        Debug.log("[\(id)] finished: \(String(describing: code)) in \(durationMs) ms")
        lastExitCode = code
        lastDurationMs = durationMs
        finishReported = true
        commandStartedAt = nil
        if let id = lastHistoryID { HistoryStore.shared.finish(id: id, exitCode: code, durationMs: durationMs) }
        onChange?(self)
    }

    func surfaceDidRequestClose(_ surface: TerminalSurface, processAlive: Bool) {
        onClose?(self)
    }

    func surfaceDidReceiveKeyInput(_ surface: TerminalSurface) {}

    private func refreshGit() {
        let dir = cwd
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let root = GitInfo.root(from: dir)
            let branch = root.flatMap(GitInfo.branch(root:))
            DispatchQueue.main.async {
                guard let self, self.cwd == dir else { return }
                self.gitRoot = root
                self.gitBranch = branch
                self.onChange?(self)
                HistoryStore.shared.prepare(self.rankContext)
            }
        }
    }
}
