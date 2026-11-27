import Foundation

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
