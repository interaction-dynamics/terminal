import XCTest
@testable import Terminal

final class ConfigTests: XCTestCase {
    func testAppKeysAndPassthrough() {
        let c = AppConfig.parse("""
        # comment
        hotkey = cmd+`
        hotkey-height = 60%
        hotkey-position = bottom
        hotkey-autohide = false
        font-size = 16
        theme = "Catppuccin Mocha"
        keybind = cmd+t=new_tab
        """)
        XCTAssertEqual(c.hotkey, "cmd+`")
        XCTAssertEqual(c.hotkeyHeight, .percent(0.6))
        XCTAssertEqual(c.hotkeyPosition, .bottom)
        XCTAssertFalse(c.hotkeyAutohide)
        XCTAssertEqual(c.ghosttyLines, ["font-size = 16", "theme = \"Catppuccin Mocha\""])
        // Forced lines come last so they always win.
        XCTAssertTrue(c.ghosttyConfigText(dark: true).hasSuffix("keybind = super+end=scroll_to_bottom\n"))
        // Conditional themes are resolved by the app, never passed to libghostty.
        XCTAssertTrue(c.ghosttyConfigText(dark: true).contains("theme = GitHub Dark Default\n"))
        XCTAssertTrue(c.ghosttyConfigText(dark: false).contains("theme = GitHub Light Default\n"))
        XCTAssertFalse(c.ghosttyConfigText(dark: false).contains("light:"))
        XCTAssertEqual(AppConfig.resolveTheme("Catppuccin Mocha", dark: true), "Catppuccin Mocha")
        XCTAssertEqual(AppConfig.resolveTheme("dark:Nord", dark: false), "Nord")
    }

    func testSizes() {
        XCTAssertEqual(AppConfig.Size("45%")?.resolve(in: 1000), 450)
        XCTAssertEqual(AppConfig.Size("300px")?.resolve(in: 1000), 300)
        XCTAssertEqual(AppConfig.Size("3000")?.resolve(in: 1000), 1000)
        XCTAssertNil(AppConfig.Size("tall"))
    }
}

final class HistoryTests: XCTestCase {
    func testPrivacyFilter() {
        XCTAssertFalse(HistoryStore.shouldSave(" secret command"))
        XCTAssertFalse(HistoryStore.shouldSave("export GITHUB_TOKEN=abc"))
        XCTAssertFalse(HistoryStore.shouldSave("curl -H 'Authorization: Bearer x' api"))
        XCTAssertFalse(HistoryStore.shouldSave("mysql --password=hunter2"))
        XCTAssertTrue(HistoryStore.shouldSave("git status"))
        XCTAssertTrue(HistoryStore.shouldSave("echo token"))
        XCTAssertFalse(HistoryStore.shouldSave("   "))
    }

    func testZshHistoryParsing() {
        let text = ": 1700000000:0;git status\n: 1700000001:0;echo one \\\ntwo\nls -la\n\n"
        XCTAssertEqual(HistoryStore.parseShellHistory(text), ["git status", "echo one \ntwo", "ls -la"])
    }
}

final class RankerTests: XCTestCase {
    private func stats(_ cmd: String, count: Int, dir: String? = nil, failures: Int = 0, age: Int64 = 0, prev: String? = nil) -> CommandStats {
        let s = CommandStats(command: cmd)
        s.count = count
        s.failures = failures
        s.lastUsed = Int64(Date().timeIntervalSince1970 * 1000) - age
        if let dir { s.dirs[dir] = count }
        if let prev { s.predecessors[prev] = count }
        return s
    }

    func testFolderBeatsFrequency() {
        let all = [
            "git push": stats("git push", count: 30),
            "git pull --rebase": stats("git pull --rebase", count: 3, dir: "/repo"),
        ]
        let ctx = RankContext(cwd: "/repo", gitRoot: nil, previousCommand: nil)
        XCTAssertEqual(Ranker.bestPrefixMatch("git p", in: all, ctx: ctx), "git pull --rebase")
    }

    func testFollowsPrevious() {
        let all = [
            "git commit -m wip": stats("git commit -m wip", count: 5),
            "git push": stats("git push", count: 2, prev: "git commit -m wip"),
            "git pull": stats("git pull", count: 4),
        ]
        let ctx = RankContext(cwd: "/x", gitRoot: nil, previousCommand: "git commit -m wip")
        XCTAssertEqual(Ranker.bestPrefixMatch("git pu", in: all, ctx: ctx), "git push")
    }

    func testFailedOnlyHidden() {
        let all = ["mkae build": stats("mkae build", count: 2, failures: 2)]
        XCTAssertNil(Ranker.bestPrefixMatch("mk", in: all, ctx: RankContext(cwd: "/", gitRoot: nil, previousCommand: nil)))
    }

    func testFuzzy() {
        XCTAssertNotNil(Ranker.fuzzyScore("gco", "git checkout"))
        XCTAssertNil(Ranker.fuzzyScore("xyz", "git checkout"))
        XCTAssertGreaterThan(Ranker.fuzzyScore("check", "git checkout")!, Ranker.fuzzyScore("gco", "git checkout")!)
    }

    func testIndexMatchesExactRanking() {
        let index = HistoryIndex()
        index.batch {
            for _ in 0..<30 { index.add("git push", cwd: "/x", repo: nil, failed: false, started: 1, previous: nil, imported: false) }
            for _ in 0..<3 { index.add("git pull --rebase", cwd: "/repo", repo: nil, failed: false, started: 1, previous: nil, imported: false) }
            index.add("mkae", cwd: "/repo", repo: nil, failed: true, started: 1, previous: nil, imported: false)
        }
        let ctx = RankContext(cwd: "/repo", gitRoot: nil, previousCommand: nil)
        XCTAssertEqual(index.bestMatch("git p", ctx: ctx), "git pull --rebase")
        XCTAssertNil(index.bestMatch("mk", ctx: ctx))
        index.add("git pull --rebase --autostash", cwd: "/x", repo: nil, failed: false, started: 2, previous: nil, imported: false)
        XCTAssertEqual(index.prefixMatches("git pull", limit: 5), ["git pull --rebase", "git pull --rebase --autostash"])
        XCTAssertEqual(index.recent.last, "git pull --rebase --autostash")
        index.remove("git pull --rebase")
        XCTAssertEqual(index.prefixMatches("git pull", limit: 5), ["git pull --rebase --autostash"])
    }

    func testGhostLookupIsFast() {
        let index = HistoryIndex()
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        index.batch {
            for i in 0..<200_000 {
                index.add("cmd\(i % 40_000) --flag \(i % 97)", cwd: i % 5 == 0 ? "/a" : "/b", repo: nil, failed: false,
                          started: now - Int64(i) * 60_000, previous: nil, imported: false)
            }
        }
        let ctx = RankContext(cwd: "/a", gitRoot: nil, previousCommand: nil)
        var start = Date()
        index.prepare(ctx)
        print("rank \(index.stats.count) distinct commands for a prompt: \(String(format: "%.1f", Date().timeIntervalSince(start) * 1000)) ms")
        // Short prefixes match most of the history: the worst case.
        for prefix in ["c", "cmd", "cmd1", "cmd1999", "cmd19999 --flag 1"] {
            start = Date()
            let best = index.bestMatch(prefix, ctx: ctx)
            let ms = Date().timeIntervalSince(start) * 1000
            XCTAssertNotNil(best, prefix)
            print("ghost lookup '\(prefix)' over 200k entries: \(String(format: "%.3f", ms)) ms")
            XCTAssertLessThan(ms, 5, "specs/06-performance.md budget")
        }
    }
}

final class CompletionTests: XCTestCase {
    func testWordContext() {
        let line = "git checkout ma"
        let ctx = WordContext.parse(line, cursor: line.endIndex)
        XCTAssertEqual(ctx.words, ["git", "checkout"])
        XCTAssertEqual(ctx.current, "ma")
        let piped = "cat a.txt | gr"
        let p = WordContext.parse(piped, cursor: piped.endIndex)
        XCTAssertEqual(p.words, [])
        XCTAssertEqual(p.current, "gr")
        let escaped = "ls My\\ Fo"
        XCTAssertEqual(WordContext.parse(escaped, cursor: escaped.endIndex).current, "My\\ Fo")
    }

    func testCommonPrefix() {
        XCTAssertEqual(TerminalContentController.commonPrefix(["src/", "spec/", "scripts/"]), "s")
        XCTAssertEqual(TerminalContentController.commonPrefix(["App/", "AppKit"]), "App")
    }

    func testHotKeyParse() {
        XCTAssertNotNil(HotKey.parse("option+space"))
        XCTAssertNotNil(HotKey.parse("cmd+shift+`"))
        XCTAssertNotNil(HotKey.parse("cmd+shift+backslash"))
        XCTAssertEqual(HotKey.parse("cmd+shift+backslash")?.0, HotKey.parse("cmd+shift+\\")?.0)
        XCTAssertNil(HotKey.parse("cmd+shift"))
    }
}
