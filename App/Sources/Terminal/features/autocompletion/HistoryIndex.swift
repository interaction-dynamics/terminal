import Foundation

/// In-memory index over the history, built for the ghost-text budget
/// (≤ 5 ms per keystroke with 200,000 entries, specs/06-performance.md).
///
/// - `sorted` holds every distinct command in byte order, so the commands
///   starting with a prefix are one binary search away.
/// - When a short prefix matches thousands of commands, scoring them all is
///   too slow. Instead the index keeps every command ranked for the current
///   context (built once per prompt, off the main thread) and returns the first
///   one that starts with the prefix.
///
/// Not thread-safe: use it from `HistoryStore.queue` only.
final class HistoryIndex {
    private(set) var stats: [String: CommandStats] = [:]
    /// Distinct commands, newest last, for ↑/↓.
    private(set) var recent: [String] = []
    private(set) var sorted: [String] = []

    private var lastSeen: [String: Int] = [:]
    private var tick = 0
    private var version = 0
    private var batching = false
    private var ranked: (key: String, version: Int, order: [String])?

    // MARK: Changes

    /// Adds many commands at once (launch, shell-history import) without
    /// keeping `sorted` and `recent` in order after each one.
    func batch(_ body: () -> Void) {
        batching = true
        body()
        batching = false
        sorted = Ranker.sortedKeys(stats)
        recent = lastSeen.sorted { $0.value < $1.value }.map(\.key)
        version += 1
    }

    func add(_ command: String, cwd: String, repo: String?, failed: Bool, started: Int64, previous: String?, imported: Bool) {
        let s: CommandStats
        if let existing = stats[command] {
            s = existing
        } else {
            s = CommandStats(command: command)
            stats[command] = s
            if !batching { sorted.insert(command, at: lowerBound(command)) }
        }
        s.count += 1
        if failed { s.failures += 1 }
        s.lastUsed = max(s.lastUsed, started)
        if imported { s.imported += 1 }
        if !cwd.isEmpty { s.dirs[cwd, default: 0] += 1 }
        if let repo { s.repos[repo, default: 0] += 1 }
        if let previous { s.predecessors[previous, default: 0] += 1 }

        tick += 1
        lastSeen[command] = tick
        if !batching {
            recent.removeAll { $0 == command }
            recent.append(command)
            version += 1
        }
    }

    func markFailed(_ command: String) {
        stats[command]?.failures += 1
        version += 1
    }

    func remove(_ command: String) {
        guard stats.removeValue(forKey: command) != nil else { return }
        lastSeen[command] = nil
        recent.removeAll { $0 == command }
        let i = lowerBound(command)
        if i < sorted.count, sorted[i] == command { sorted.remove(at: i) }
        version += 1
    }

    // MARK: Lookups

    /// Best command to show as ghost text after `prefix`.
    func bestMatch(_ prefix: String, ctx: RankContext) -> String? {
        guard !prefix.isEmpty else { return nil }
        let range = prefixRange(prefix)
        if range.count <= RankTuning.exactScanLimit {
            return Ranker.bestPrefixMatch(prefix, sorted: sorted, range: range, stats: stats, ctx: ctx)
        }
        let n = prefix.utf8.count
        return rankedOrder(ctx).first { $0.utf8.count > n && $0.utf8.starts(with: prefix.utf8) }
    }

    /// Commands starting with `prefix`, in byte order.
    func prefixMatches(_ prefix: String, limit: Int) -> [String] {
        let range = prefixRange(prefix)
        return Array(sorted[range.lowerBound..<min(range.upperBound, range.lowerBound + limit)])
    }

    /// Ranks every command for this context so the next lookups are fast.
    /// Called when the prompt comes back, before the user types.
    func prepare(_ ctx: RankContext) {
        _ = rankedOrder(ctx)
    }

    private func rankedOrder(_ ctx: RankContext) -> [String] {
        let key = "\(ctx.cwd)\u{0}\(ctx.gitRoot ?? "")\u{0}\(ctx.previousCommand ?? "")"
        if let r = ranked, r.key == key, r.version == version { return r.order }
        var scored: [(String, Double)] = []
        scored.reserveCapacity(stats.count)
        for (cmd, s) in stats where s.failures < s.count {
            scored.append((cmd, Ranker.score(s, ctx)))
        }
        scored.sort { $0.1 > $1.1 }
        let order = scored.map(\.0)
        ranked = (key, version, order)
        return order
    }

    private func lowerBound(_ s: String) -> Int {
        var lo = 0, hi = sorted.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if sorted[mid].utf8.lexicographicallyPrecedes(s.utf8) { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }

    /// Indices of `sorted` whose command starts with `prefix` (they are contiguous).
    private func prefixRange(_ prefix: String) -> Range<Int> {
        let lo = lowerBound(prefix)
        var a = lo, b = sorted.count
        while a < b {
            let mid = (a + b) / 2
            if sorted[mid].utf8.starts(with: prefix.utf8) { a = mid + 1 } else { b = mid }
        }
        return lo..<a
    }
}
