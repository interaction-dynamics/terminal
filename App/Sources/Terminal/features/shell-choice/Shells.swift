import Foundation

enum Shells {
    /// Where shells live besides /etc/shells (Homebrew on Apple silicon and Intel).
    static let extraPaths = ["/opt/homebrew/bin", "/usr/local/bin"]
    static let extraNames = ["zsh", "bash", "fish", "nu", "xonsh", "elvish"]

    /// The user's login shell (from the user database, not $SHELL).
    static var login: String {
        if let pw = getpwuid(getuid()), let shell = pw.pointee.pw_shell { return String(cString: shell) }
        return ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    }

    /// Installed shells: /etc/shells, then the usual Homebrew ones. Only executables.
    static func available() -> [String] {
        let listed = (try? String(contentsOfFile: "/etc/shells", encoding: .utf8)).map(parse) ?? []
        let extra = extraPaths.flatMap { dir in extraNames.map { "\(dir)/\($0)" } }
        var seen = Set<String>()
        return (listed + extra).filter { FileManager.default.isExecutableFile(atPath: $0) && seen.insert($0).inserted }
    }

    /// Paths from an /etc/shells file (comments and blank lines skipped).
    static func parse(_ text: String) -> [String] {
        text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.hasPrefix("/") }
    }

    /// The shell new tabs run: the configured one if it can run, else the login shell.
    static func resolved(_ configured: String) -> String {
        configured.isEmpty || !FileManager.default.isExecutableFile(atPath: configured) ? login : configured
    }

    /// "zsh", "bash"…
    static func name(_ path: String) -> String { (path as NSString).lastPathComponent }

    /// Only zsh has the shell integration (smart input, command blocks) for now.
    static func hasIntegration(_ path: String) -> Bool { name(path) == "zsh" }
}


extension Shells {
    /// Saves the choice: the login shell is the default, so it removes the line.
    static func choose(_ path: String) {
        AppConfig.update("shell", to: path == login ? nil : path)
    }
}
