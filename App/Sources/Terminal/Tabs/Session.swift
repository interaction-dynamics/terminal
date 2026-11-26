import AppKit

/// One tab: a shell, its terminal surface and the smart-input state (specs/04-smart-input.md).
final class Session: TerminalSurfaceDelegate {
    enum State: Equatable {
        /// No prompt mark seen yet (or none ever: ssh, other shells). Plain terminal.
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
    var draft = ""

    init(workingDirectory: String?, smartInput: Bool) {
        let cwd = workingDirectory ?? FileManager.default.homeDirectoryForCurrentUser.path
        self.cwd = cwd
        var env: [String: String] = ["TERMINAL_SESSION_ID": id, "TERM_PROGRAM": "Terminal-libghostty"]
        if let integration = Bundle.main.resourceURL?.appendingPathComponent("shell-integration/zsh"),
           FileManager.default.fileExists(atPath: integration.appendingPathComponent(".zshenv").path),
           Self.userShell.hasSuffix("/zsh") {
            if let existing = ProcessInfo.processInfo.environment["ZDOTDIR"] { env["TERMINAL_ZSH_ZDOTDIR"] = existing }
            env["ZDOTDIR"] = integration.path
            env["TERMINAL_SMART_INPUT"] = smartInput ? "1" : "0"
        }
        Debug.log("[\(id)] new session env: \(env)")
        surface = TerminalSurfaceView(options: SurfaceOptions(workingDirectory: cwd, environment: env))
        surface.delegate = self
        refreshGit()
    }

    static var userShell: String {
        if let pw = getpwuid(getuid()), let shell = pw.pointee.pw_shell { return String(cString: shell) }
        return ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    }

    /// Label for the tab: the running command, else the folder name.
    var label: String {
        if state == .running, let cmd = runningCommand {
            return String(cmd.split(separator: " ").first ?? Substring(cmd))
        }
        if !title.isEmpty, state == .noIntegration { return title }
        return cwd == NSHomeDirectory() ? "~" : (cwd as NSString).lastPathComponent
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
        if trimmed.isEmpty {
            surface.sendKey(.enter)
            return
        }
        state = .running
        runningCommand = trimmed
        commandStartedAt = Date()
        lastExitCode = nil
        lastDurationMs = nil
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
        if wasRunning, let started = commandStartedAt, lastDurationMs == nil {
            lastDurationMs = Int(Date().timeIntervalSince(started) * 1000)
        }
        commandStartedAt = nil
        state = .atPrompt
        runningCommand = nil
        onChange?(self)
        HistoryStore.shared.prepare(rankContext)
    }

    func surface(_ surface: TerminalSurface, didFinishCommandWithExitCode code: Int?, durationMs: Int) {
        Debug.log("[\(id)] finished: \(String(describing: code)) in \(durationMs) ms")
        lastExitCode = code
        lastDurationMs = durationMs
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
