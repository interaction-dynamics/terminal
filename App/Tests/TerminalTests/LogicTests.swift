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
        XCTAssertEqual(c.theme, "Catppuccin Mocha")
        XCTAssertTrue(c.ghosttyConfigText(dark: true).contains("theme = Catppuccin Mocha\n"))
        XCTAssertEqual(AppConfig.resolveTheme("Catppuccin Mocha", dark: true), "Catppuccin Mocha")
        XCTAssertEqual(AppConfig.resolveTheme("dark:Nord", dark: false), "Nord")
    }

    func testThemesAndTabs() {
        // Default: midnight, tabs on the left.
        let d = AppConfig.parse("")
        XCTAssertEqual(d.theme, "midnight")
        XCTAssertEqual(d.tabsPosition, .left)
        XCTAssertTrue(d.ghosttyConfigText(dark: false).contains("background = 0e0e0e\n"))
        // Conditional themes are resolved by the app, never passed to libghostty.
        let auto = AppConfig.parse("theme = auto")
        XCTAssertTrue(auto.ghosttyConfigText(dark: false).contains("theme = GitHub Light Default\n"))
        XCTAssertTrue(auto.ghosttyConfigText(dark: true).contains("background = 0e0e0e\n"))
        let split = AppConfig.parse("theme = light:paper,dark:frost")
        XCTAssertTrue(split.ghosttyConfigText(dark: true).contains("theme = Nord\n"))
        XCTAssertFalse(split.ghosttyConfigText(dark: false).contains("light:"))
        // The user's colours come after the theme's, so they win.
        let custom = AppConfig.parse("background = 000000")
        let text = custom.ghosttyConfigText(dark: true)
        XCTAssertLessThan(text.range(of: "background = 0e0e0e")!.lowerBound, text.range(of: "background = 000000")!.lowerBound)
        let t = AppConfig.parse("tabs-position = top\ntabs-width = 9999")
        XCTAssertEqual(t.tabsPosition, .top)
        XCTAssertEqual(t.tabsWidth, AppConfig.tabsWidthRange.upperBound)
    }

    func testUpdateKeepsOtherLines() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("terminal"), withIntermediateDirectories: true)
        setenv("XDG_CONFIG_HOME", dir.path, 1)
        defer { unsetenv("XDG_CONFIG_HOME"); try? FileManager.default.removeItem(at: dir) }
        try "# mine\ntheme = Nord\nfont-family = Iosevka\ntheme = frost\n".write(to: AppConfig.fileURL, atomically: true, encoding: .utf8)
        AppConfig.update("theme", to: "paper")
        AppConfig.update("tabs-position", to: "right")
        AppConfig.update("font-family", to: nil)
        XCTAssertEqual(try String(contentsOf: AppConfig.fileURL, encoding: .utf8), "# mine\ntheme = paper\ntabs-position = right\n")
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
