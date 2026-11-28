import Foundation
import SQLite3

/// One past command with the context the app saw when it ran.
struct HistoryEntry {
    var id: Int64 = 0
    var command: String
    var cwd: String
    var gitRoot: String?
    var exitCode: Int?
    var startedAt: Int64
    var durationMs: Int?
    var sessionID: String
    var prevID: Int64?
    var imported = false
}

/// Aggregated view of one distinct command, kept in memory for fast ranking.
final class CommandStats {
    let command: String
    var count = 0
    var failures = 0
    var lastUsed: Int64 = 0
    var imported = 0
    var dirs: [String: Int] = [:]
    var repos: [String: Int] = [:]
    /// Commands that came just before this one in the same tab, with counts.
    var predecessors: [String: Int] = [:]

    init(command: String) { self.command = command }
}

/// Local SQLite history (specs/05-autocompletion.md). Never synced.
/// All database work runs on one serial background queue.
final class HistoryStore {
    static let shared = HistoryStore()

    private var db: OpaquePointer?
    let queue = DispatchQueue(label: "terminal.history", qos: .userInitiated)
    /// Distinct commands, built at launch and kept up to date. Accessed on `queue`.
    let index = HistoryIndex()
    /// Copy of `index.recent` for ↑/↓ on the main thread, so it never waits on `queue`.
    private(set) var recentSnapshot: [String] = []
    private var commandByID: [Int64: String] = [:]

    /// Ghost-text lookup; `completion` runs on the main thread.
    func bestMatch(_ prefix: String, ctx: RankContext, completion: @escaping (String?) -> Void) {
        queue.async {
            let best = self.index.bestMatch(prefix, ctx: ctx)
            DispatchQueue.main.async { completion(best) }
        }
    }

    /// Ranks history for a new prompt so the first keystrokes are fast.
    func prepare(_ ctx: RankContext) {
        queue.async { self.index.prepare(ctx) }
    }

    private func publishRecent() {
        let recent = index.recent
        DispatchQueue.main.async { self.recentSnapshot = recent }
    }

    static var databaseURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Terminal", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.sqlite")
    }

    init(url: URL = HistoryStore.databaseURL) {
        queue.async { self.open(url) }
    }

    private func open(_ url: URL) {
        guard sqlite3_open(url.path, &db) == SQLITE_OK else { return }
        exec("PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL;")
        exec("""
        CREATE TABLE IF NOT EXISTS commands (
          id           INTEGER PRIMARY KEY,
          command      TEXT    NOT NULL,
          cwd          TEXT    NOT NULL,
          git_root     TEXT,
          exit_code    INTEGER,
          started_at   INTEGER NOT NULL,
          duration_ms  INTEGER,
          session_id   TEXT    NOT NULL,
          prev_id      INTEGER REFERENCES commands(id),
          imported     INTEGER NOT NULL DEFAULT 0
        );
        CREATE INDEX IF NOT EXISTS idx_commands_command ON commands(command);
        CREATE INDEX IF NOT EXISTS idx_commands_cwd     ON commands(cwd);
        CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT);
        """)
        index.batch { loadAll() }
        publishRecent()
    }

    private func exec(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private func loadAll() {
        var stmt: OpaquePointer?
        let sql = "SELECT id, command, cwd, git_root, exit_code, started_at, prev_id, imported FROM commands ORDER BY id"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_int64(stmt, 0)
            let command = String(cString: sqlite3_column_text(stmt, 1))
            let cwd = String(cString: sqlite3_column_text(stmt, 2))
            let repo = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
            let exit: Int? = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 4))
            let started = sqlite3_column_int64(stmt, 5)
            let prev: Int64? = sqlite3_column_type(stmt, 6) == SQLITE_NULL ? nil : sqlite3_column_int64(stmt, 6)
            let imported = sqlite3_column_int(stmt, 7) != 0
            absorb(id: id, command: command, cwd: cwd, repo: repo, exit: exit, started: started, prev: prev, imported: imported)
        }
    }

    private func absorb(id: Int64, command: String, cwd: String, repo: String?, exit: Int?, started: Int64, prev: Int64?, imported: Bool) {
        let previous = prev.flatMap { commandByID[$0] }
        index.add(command, cwd: cwd, repo: repo, failed: exit.map { $0 != 0 } ?? false,
                  started: started, previous: previous, imported: imported)
        commandByID[id] = command
    }

    /// Records a command. Returns its row id (for `prev_id` and exit-code updates).
    func record(_ entry: HistoryEntry, completion: ((Int64) -> Void)? = nil) {
        guard Self.shouldSave(entry.command) else { return }
        queue.async {
            var stmt: OpaquePointer?
            let sql = "INSERT INTO commands (command, cwd, git_root, exit_code, started_at, duration_ms, session_id, prev_id, imported) VALUES (?,?,?,?,?,?,?,?,?)"
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            self.bind(stmt, 1, entry.command)
            self.bind(stmt, 2, entry.cwd)
            self.bind(stmt, 3, entry.gitRoot)
            if let e = entry.exitCode { sqlite3_bind_int(stmt, 4, Int32(e)) } else { sqlite3_bind_null(stmt, 4) }
            sqlite3_bind_int64(stmt, 5, entry.startedAt)
            if let d = entry.durationMs { sqlite3_bind_int(stmt, 6, Int32(d)) } else { sqlite3_bind_null(stmt, 6) }
            self.bind(stmt, 7, entry.sessionID)
            if let p = entry.prevID { sqlite3_bind_int64(stmt, 8, p) } else { sqlite3_bind_null(stmt, 8) }
            sqlite3_bind_int(stmt, 9, entry.imported ? 1 : 0)
            guard sqlite3_step(stmt) == SQLITE_DONE else { return }
            let id = sqlite3_last_insert_rowid(self.db)
            self.absorb(id: id, command: entry.command, cwd: entry.cwd, repo: entry.gitRoot, exit: entry.exitCode,
                        started: entry.startedAt, prev: entry.prevID, imported: entry.imported)
            self.publishRecent()
            completion?(id)
        }
    }

    /// Stores the result once the command finishes.
    func finish(id: Int64, exitCode: Int?, durationMs: Int) {
        queue.async {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(self.db, "UPDATE commands SET exit_code = ?, duration_ms = ? WHERE id = ?", -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            if let e = exitCode { sqlite3_bind_int(stmt, 1, Int32(e)) } else { sqlite3_bind_null(stmt, 1) }
            sqlite3_bind_int(stmt, 2, Int32(durationMs))
            sqlite3_bind_int64(stmt, 3, id)
            sqlite3_step(stmt)
            if let exitCode, exitCode != 0, let cmd = self.commandByID[id] { self.index.markFailed(cmd) }
        }
    }

    /// Deletes every row of a command (from the Ctrl+R popup).
    func delete(command: String) {
        queue.async {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(self.db, "DELETE FROM commands WHERE command = ?", -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            self.bind(stmt, 1, command)
            sqlite3_step(stmt)
            self.index.remove(command)
            self.publishRecent()
        }
    }

    private func bind(_ stmt: OpaquePointer?, _ index: Int32, _ value: String?) {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        if let value { sqlite3_bind_text(stmt, index, value, -1, transient) } else { sqlite3_bind_null(stmt, index) }
    }

    // MARK: Import

    /// Imports ~/.zsh_history (and bash/fish) once, so suggestions work on day one.
    func importShellHistoryOnce() {
        queue.async {
            guard self.meta("imported") == nil else { return }
            let home = FileManager.default.homeDirectoryForCurrentUser
            var commands: [String] = []
            for name in [".zsh_history", ".bash_history"] {
                if let data = try? Data(contentsOf: home.appendingPathComponent(name)) {
                    commands += Self.parseShellHistory(String(decoding: data, as: UTF8.self))
                }
            }
            if let fish = try? String(contentsOf: home.appendingPathComponent(".local/share/fish/fish_history"), encoding: .utf8) {
                commands += fish.split(separator: "\n").compactMap { line in
                    line.hasPrefix("- cmd: ") ? String(line.dropFirst(7)) : nil
                }
            }
            self.exec("BEGIN")
            self.index.batch {
                let now = Int64(Date().timeIntervalSince1970 * 1000) - Int64(commands.count)
                for (i, cmd) in commands.enumerated() where Self.shouldSave(cmd) {
                    var stmt: OpaquePointer?
                    guard sqlite3_prepare_v2(self.db, "INSERT INTO commands (command, cwd, started_at, session_id, imported) VALUES (?, '', ?, 'import', 1)", -1, &stmt, nil) == SQLITE_OK else { continue }
                    self.bind(stmt, 1, cmd)
                    sqlite3_bind_int64(stmt, 2, now + Int64(i))
                    if sqlite3_step(stmt) == SQLITE_DONE {
                        self.absorb(id: sqlite3_last_insert_rowid(self.db), command: cmd, cwd: "", repo: nil, exit: nil,
                                    started: now + Int64(i), prev: nil, imported: true)
                    }
                    sqlite3_finalize(stmt)
                }
            }
            self.exec("COMMIT")
            self.publishRecent()
            self.setMeta("imported", "1")
        }
    }

    /// Parses zsh extended history (`: 1700000000:0;cmd`), plain lines and
    /// backslash-continued multi-line commands.
    static func parseShellHistory(_ text: String) -> [String] {
        var result: [String] = []
        var pending: String?
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            var line = String(raw)
            if pending == nil, line.hasPrefix(": "), let semi = line.firstIndex(of: ";") {
                line = String(line[line.index(after: semi)...])
            }
            if let p = pending { line = p + "\n" + line }
            if line.hasSuffix("\\") {
                pending = String(line.dropLast())
                continue
            }
            pending = nil
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { result.append(trimmed) }
        }
        return result
    }

    private func meta(_ key: String) -> String? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT value FROM meta WHERE key = ?", -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, key)
        guard sqlite3_step(stmt) == SQLITE_ROW, let v = sqlite3_column_text(stmt, 0) else { return nil }
        return String(cString: v)
    }

    private func setMeta(_ key: String, _ value: String) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)", -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, key)
        bind(stmt, 2, value)
        sqlite3_step(stmt)
    }

    // MARK: Privacy

    private static let secretPatterns: [NSRegularExpression] = [
        #"(?i)export\s+\S*(TOKEN|SECRET|PASSWORD|PASSWD|API_?KEY)\S*="#,
        #"(?i)\S*(TOKEN|SECRET|PASSWORD|PASSWD|API_?KEY)\S*=\S+"#,
        #"(?i)authorization:"#,
        #"(?i)bearer\s+[a-z0-9._-]{16,}"#,
        #"(?i)--password[= ]"#,
        #"\b(sk|pk|ghp|gho|xox[abpr])[-_][A-Za-z0-9_-]{16,}"#,
    ].map { try! NSRegularExpression(pattern: $0) }

    /// Commands starting with a space, and ones that look like they hold a secret, are never saved.
    static func shouldSave(_ command: String) -> Bool {
        if command.hasPrefix(" ") { return false }
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        return !secretPatterns.contains { $0.firstMatch(in: trimmed, range: range) != nil }
    }
}
