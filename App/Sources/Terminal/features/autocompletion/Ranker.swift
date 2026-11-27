import Foundation

/// Every ranking weight lives here, so they are easy to tune (specs/05-autocompletion.md).
enum RankWeights {
    static let sameFolder = 4.0
    static let sameRepo = 2.0
    static let followsPrevious = 4.0
    static let frequency = 1.0          // × log2(1 + count)
    static let recency = 3.0            // × exp(-age / recencyHalfLifeDays)
    static let recencyHalfLifeDays = 7.0
    static let failedPenalty = 3.0      // × failure ratio
    static let importedPenalty = 1.5    // × imported ratio
}

/// Lookup tuning (specs/06-performance.md).
enum RankTuning {
    /// Up to this many prefix matches are scored one by one; above it the
    /// per-prompt ranked list is used instead.
    static let exactScanLimit = 3000
}

/// Where the user is when asking for a suggestion.
struct RankContext {
    var cwd: String
    var gitRoot: String?
    var previousCommand: String?
    var now = Int64(Date().timeIntervalSince1970 * 1000)
}

enum Ranker {
    static func score(_ s: CommandStats, _ ctx: RankContext) -> Double {
        let count = Double(max(s.count, 1))
        var score = RankWeights.frequency * log2(1 + count)

        let ageDays = Double(max(ctx.now - s.lastUsed, 0)) / 86_400_000
        score += RankWeights.recency * exp(-ageDays / RankWeights.recencyHalfLifeDays)

        if let n = s.dirs[ctx.cwd], n > 0 {
            score += RankWeights.sameFolder * min(1, log2(1 + Double(n)) / 2)
        } else if let repo = ctx.gitRoot, let n = s.repos[repo], n > 0 {
            score += RankWeights.sameRepo * min(1, log2(1 + Double(n)) / 2)
        }
        if let prev = ctx.previousCommand, let n = s.predecessors[prev], n > 0 {
            score += RankWeights.followsPrevious * min(1, Double(n) / 2)
        }
        score -= RankWeights.failedPenalty * Double(s.failures) / count
        score -= RankWeights.importedPenalty * Double(s.imported) / count
        return score
    }

    /// Best history command starting with `prefix` (ghost text), scoring every
    /// candidate in `range` of `sorted`. Commands that only ever failed are skipped.
    static func bestPrefixMatch(_ prefix: String, sorted: [String], range: Range<Int>, stats: [String: CommandStats], ctx: RankContext) -> String? {
        let n = prefix.utf8.count
        var best: (String, Double)?
        for cmd in sorted[range] {
            guard cmd.utf8.count > n, let s = stats[cmd], s.failures < s.count else { continue }
            let sc = score(s, ctx)
            if best == nil || sc > best!.1 { best = (cmd, sc) }
        }
        return best?.0
    }

    /// Exact lookup over a plain dictionary, for tests and small sets.
    static func bestPrefixMatch(_ prefix: String, in stats: [String: CommandStats], ctx: RankContext) -> String? {
        let matches = sortedKeys(stats).filter { $0.utf8.starts(with: prefix.utf8) }
        return bestPrefixMatch(prefix, sorted: matches, range: matches.indices, stats: stats, ctx: ctx)
    }

    static func sortedKeys(_ stats: [String: CommandStats]) -> [String] {
        stats.keys.sorted { $0.utf8.lexicographicallyPrecedes($1.utf8) }
    }

    /// Fuzzy matches for Ctrl+R, best first.
    static func fuzzyMatches(_ query: String, in stats: [String: CommandStats], ctx: RankContext, limit: Int = 50) -> [String] {
        let q = query.lowercased()
        var scored: [(String, Double)] = []
        scored.reserveCapacity(min(stats.count, 4096))
        for (cmd, s) in stats {
            guard let fuzzy = fuzzyScore(q, cmd.lowercased()) else { continue }
            scored.append((cmd, score(s, ctx) + fuzzy))
        }
        scored.sort { $0.1 > $1.1 }
        return scored.prefix(limit).map(\.0)
    }

    /// Subsequence match: nil if `query` is not a subsequence. Contiguous and early matches score higher.
    static func fuzzyScore(_ query: String, _ text: String) -> Double? {
        if query.isEmpty { return 0 }
        if let r = text.range(of: query) {
            let early = text.distance(from: text.startIndex, to: r.lowerBound)
            return 6 - min(Double(early) / 10, 2)
        }
        var qi = query.startIndex
        var gaps = 0
        var lastMatch: String.Index?
        for i in text.indices {
            guard qi < query.endIndex else { break }
            if text[i] == query[qi] {
                if let last = lastMatch, text.index(after: last) != i { gaps += 1 }
                lastMatch = i
                qi = query.index(after: qi)
            }
        }
        guard qi == query.endIndex else { return nil }
        return 3 - min(Double(gaps) * 0.5, 3)
    }
}
