import Foundation

struct Completion: Equatable {
    enum Kind { case folder, file, command, branch, script, subcommand, history }
    var replacement: String   // replaces the current word
    var display: String
    var kind: Kind
}

/// The word under the cursor and where it sits in the line.
struct WordContext {
    var words: [String]       // words before the current one
    var current: String       // text of the current word up to the cursor
    var range: Range<String.Index>

    static func parse(_ line: String, cursor: String.Index) -> WordContext {
        let head = line[..<cursor]
        var words: [String] = []
        var word = ""
        var wordStart = head.startIndex
        var quote: Character?
        var escaped = false
        var i = head.startIndex
        while i < head.endIndex {
            let c = head[i]
            if escaped { word.append(c); escaped = false }
            else if c == "\\" { escaped = true; word.append(c) }
            else if let q = quote { if c == q { quote = nil }; word.append(c) }
            else if c == "\"" || c == "'" { quote = c; word.append(c) }
            else if c == " " || c == "\t" {
                if !word.isEmpty { words.append(word) }
                word = ""
                wordStart = head.index(after: i)
            } else if c == "|" || c == ";" || c == "&" {
                // A new command starts after a pipe or separator.
                words = []
                word = ""
                wordStart = head.index(after: i)
            } else { word.append(c) }
            i = head.index(after: i)
        }
        return WordContext(words: words, current: word, range: wordStart..<cursor)
    }
}

/// Tab completion: paths, commands from $PATH, a few native argument generators, then history.
final class Completer {
    static let shared = Completer()
    private let queue = DispatchQueue(label: "terminal.completion", qos: .userInitiated)
    private var pathCommands: [String]?
    private var loadingPath = false

    /// Loads the user's $PATH commands once, the first time completion is used.
    func warmUp() {
        queue.async { _ = self.commands() }
    }

    func complete(line: String, cursor: String.Index, cwd: String, completion: @escaping ([Completion]) -> Void) {
        let ctx = WordContext.parse(line, cursor: cursor)
        queue.async {
            let items = self.items(for: ctx, cwd: cwd)
            DispatchQueue.main.async { completion(items) }
        }
    }

    private func items(for ctx: WordContext, cwd: String) -> [Completion] {
        let word = ctx.current
        if ctx.words.isEmpty, !word.contains("/"), !word.hasPrefix(".") , !word.hasPrefix("~") {
            let cmds = commands().filter { $0.hasPrefix(word) }.prefix(200)
            return cmds.map { Completion(replacement: $0 + " ", display: $0, kind: .command) }
        }
        var result: [Completion] = []
        if let cmd = ctx.words.first, !word.hasPrefix("-") {
            result += generators(command: cmd, args: Array(ctx.words.dropFirst()), word: word, cwd: cwd)
        }
        result += paths(word: word, cwd: cwd, foldersOnly: ctx.words.first == "cd")
        if result.isEmpty {
            let line = (ctx.words + [word]).joined(separator: " ")
            let matches = HistoryStore.shared.queue.sync { HistoryStore.shared.index.prefixMatches(line, limit: 21) }
                .filter { $0 != line }.prefix(20)
            result += matches.compactMap { cmd in
                let rest = cmd.dropFirst(line.count - word.count)
                return Completion(replacement: String(rest), display: cmd, kind: .history)
            }
        }
        return result
    }

    // MARK: Paths

    private func paths(word: String, cwd: String, foldersOnly: Bool) -> [Completion] {
        let unescaped = word.replacingOccurrences(of: "\\ ", with: " ")
        let expanded = unescaped.hasPrefix("~") ? NSHomeDirectory() + unescaped.dropFirst() : unescaped
        let dirPart: String
        let namePrefix: String
        if let slash = expanded.lastIndex(of: "/") {
            dirPart = String(expanded[...slash])
            namePrefix = String(expanded[expanded.index(after: slash)...])
        } else {
            dirPart = ""
            namePrefix = expanded
        }
        let base = dirPart.hasPrefix("/") ? dirPart : (cwd as NSString).appendingPathComponent(dirPart)
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: base.isEmpty ? cwd : base) else { return [] }
        // Keep what the user typed for the folder part (e.g. "~/Dev/"), replace only the name.
        let typedDir = word.lastIndex(of: "/").map { String(word[...$0]) } ?? ""
        var out: [Completion] = []
        for name in names.sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending }) {
            if name.hasPrefix(".") && !namePrefix.hasPrefix(".") { continue }
            guard name.hasPrefix(namePrefix) else { continue }
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: (base as NSString).appendingPathComponent(name), isDirectory: &isDir)
            if foldersOnly && !isDir.boolValue { continue }
            let rep = typedDir + escape(name) + (isDir.boolValue ? "/" : " ")
            out.append(Completion(replacement: rep, display: name + (isDir.boolValue ? "/" : ""), kind: isDir.boolValue ? .folder : .file))
            if out.count >= 300 { break }
        }
        return out
    }

    private func escape(_ name: String) -> String {
        var s = ""
        for c in name {
            if " '\"()&;|<>$`\\!*?[]#~".contains(c) { s.append("\\") }
            s.append(c)
        }
        return s
    }

    // MARK: Commands on $PATH

    private func commands() -> [String] {
        if let pathCommands { return pathCommands }
        let path = Self.loginPath()
        var set = Set<String>()
        for dir in path.split(separator: ":") {
            guard let names = try? FileManager.default.contentsOfDirectory(atPath: String(dir)) else { continue }
            for n in names where !n.hasPrefix(".") { set.insert(n) }
        }
        for builtin in ["cd", "export", "source", "alias", "unset", "exit", "history", "pushd", "popd", "echo", "eval", "exec", "which", "type"] {
            set.insert(builtin)
        }
        let list = set.sorted()
        pathCommands = list
        return list
    }

    /// The PATH an interactive login zsh sets up (GUI apps start with a minimal one).
    static func loginPath() -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-ilc", "print -rn -- $PATH"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        proc.standardInput = FileHandle.nullDevice
        do { try proc.run() } catch { return ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin" }
        let deadline = Date().addingTimeInterval(2)
        while proc.isRunning && Date() < deadline { usleep(10_000) }
        if proc.isRunning { proc.terminate() }
        let out = String(decoding: pipe.fileHandleForReading.availableData, as: UTF8.self)
        let last = out.split(separator: "\n").last.map(String.init) ?? ""
        return last.contains("/") ? last : (ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin")
    }

    // MARK: Native generators (a small stand-in for Fig specs)

    private static let gitSubcommands = ["add", "bisect", "blame", "branch", "checkout", "cherry-pick", "clone", "commit", "diff", "fetch", "init", "log", "merge", "mv", "pull", "push", "rebase", "remote", "reset", "restore", "revert", "rm", "show", "stash", "status", "switch", "tag", "worktree"]

    private func generators(command: String, args: [String], word: String, cwd: String) -> [Completion] {
        switch command {
        case "git":
            if args.isEmpty {
                return Self.gitSubcommands.filter { $0.hasPrefix(word) }.map { Completion(replacement: $0 + " ", display: $0, kind: .subcommand) }
            }
            if ["checkout", "switch", "merge", "rebase", "branch", "diff", "log", "cherry-pick", "reset"].contains(args[0]) {
                return gitBranches(cwd: cwd).filter { $0.hasPrefix(word) }.map { Completion(replacement: $0 + " ", display: $0, kind: .branch) }
            }
        case "npm", "bun", "pnpm", "yarn":
            if args.isEmpty || args == ["run"] {
                let scripts = packageScripts(cwd: cwd).filter { $0.hasPrefix(word) }
                return scripts.map { Completion(replacement: $0 + " ", display: $0, kind: .script) }
            }
        case "make":
            return makeTargets(cwd: cwd).filter { $0.hasPrefix(word) }.map { Completion(replacement: $0 + " ", display: $0, kind: .script) }
        default:
            break
        }
        return []
    }

    func gitBranches(cwd: String) -> [String] {
        guard let root = GitInfo.root(from: cwd) else { return [] }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        proc.arguments = ["-C", root, "for-each-ref", "--format=%(refname:short)", "refs/heads", "refs/remotes"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do { try proc.run() } catch { return [] }
        // 300 ms budget for generators (specs/05-autocompletion.md).
        let deadline = Date().addingTimeInterval(0.3)
        while proc.isRunning && Date() < deadline { usleep(5_000) }
        if proc.isRunning { proc.terminate(); return [] }
        return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .split(separator: "\n").map(String.init).filter { !$0.hasSuffix("/HEAD") }
    }

    private func packageScripts(cwd: String) -> [String] {
        var dir = URL(fileURLWithPath: cwd)
        for _ in 0..<8 {
            let pkg = dir.appendingPathComponent("package.json")
            if let data = try? Data(contentsOf: pkg),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let scripts = json["scripts"] as? [String: Any] {
                return scripts.keys.sorted()
            }
            dir.deleteLastPathComponent()
        }
        return []
    }

    private func makeTargets(cwd: String) -> [String] {
        guard let text = try? String(contentsOfFile: (cwd as NSString).appendingPathComponent("Makefile"), encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            guard let colon = line.firstIndex(of: ":"), !line.hasPrefix("\t"), !line.hasPrefix("."), !line.contains("=") else { return nil }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces)
            return name.isEmpty || name.contains(" ") ? nil : name
        }
    }
}

/// Git folder and branch, read straight from `.git` (no process spawned).
enum GitInfo {
    static func root(from cwd: String) -> String? {
        var dir = URL(fileURLWithPath: cwd)
        while true {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent(".git").path) { return dir.path }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { return nil }
            dir = parent
        }
    }

    static func branch(root: String) -> String? {
        var gitDir = URL(fileURLWithPath: root).appendingPathComponent(".git")
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: gitDir.path, isDirectory: &isDir)
        if !isDir.boolValue, let text = try? String(contentsOf: gitDir, encoding: .utf8),
           let line = text.split(separator: "\n").first, line.hasPrefix("gitdir: ") {
            // Worktree or submodule: `.git` is a file pointing at the real git dir.
            let path = String(line.dropFirst(8))
            gitDir = path.hasPrefix("/") ? URL(fileURLWithPath: path) : URL(fileURLWithPath: root).appendingPathComponent(path)
        }
        guard let head = try? String(contentsOf: gitDir.appendingPathComponent("HEAD"), encoding: .utf8) else { return nil }
        let h = head.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("ref: refs/heads/") { return String(h.dropFirst(16)) }
        return String(h.prefix(7))
    }
}
