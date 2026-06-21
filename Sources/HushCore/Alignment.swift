import Foundation

/// Bounded local sequence alignment (Smith–Waterman) used to locate where a
/// short tail of recognized words best maps onto a window of script words.
///
/// Similarity is exact-match dominant with a forgiving fallback (shared prefix
/// or small edit distance) so ASR drift like "scroll"→"scrawl" still scores.
/// A future pass can swap the fallback for true phonetic matching (Metaphone).
public enum Alignment {

    /// Returns the window index aligned to the END of the best local match and
    /// a score normalized to 0...1 (1.0 = every tail word matched exactly).
    public static func bestLocalAlignment(tail: [String], window: [String], config: SyncConfig) -> (endIndex: Int, score: Double) {
        let m = tail.count, w = window.count
        guard m > 0, w > 0 else { return (-1, 0) }

        var prev = [Int](repeating: 0, count: w + 1)
        var curr = [Int](repeating: 0, count: w + 1)
        var best = 0, bestJ = 0

        for i in 1...m {
            for j in 1...w {
                let s = sim(tail[i - 1], window[j - 1], config)
                let diag = prev[j - 1] + s
                let up = prev[j] + config.gapScore
                let left = curr[j - 1] + config.gapScore
                let v = max(0, max(diag, max(up, left)))
                curr[j] = v
                if v >= best { best = v; bestJ = j }
            }
            swap(&prev, &curr)
            for k in 0...w { curr[k] = 0 }
        }

        let norm = Double(best) / Double(m * config.matchScore)
        return (bestJ - 1, min(1.0, norm))
    }

    public static func sim(_ a: String, _ b: String, _ c: SyncConfig) -> Int {
        if a == b { return c.matchScore }
        // single-letter tokens (spelled-out acronyms) must match exactly,
        // otherwise "a" vs "p" would score as a near-miss.
        if a.count == 1 || b.count == 1 { return c.mismatchScore }
        if a.prefix(3) == b.prefix(3) { return c.partialScore }
        if levenshtein(a, b) <= 2 { return c.partialScore }
        return c.mismatchScore
    }

    static func levenshtein(_ a: String, _ b: String) -> Int {
        let aa = Array(a), bb = Array(b)
        if aa.isEmpty { return bb.count }
        if bb.isEmpty { return aa.count }
        var d = Array(0...bb.count)
        for i in 1...aa.count {
            var prev = d[0]
            d[0] = i
            for j in 1...bb.count {
                let tmp = d[j]
                d[j] = aa[i - 1] == bb[j - 1] ? prev : Swift.min(prev, Swift.min(d[j], d[j - 1])) + 1
                prev = tmp
            }
        }
        return d[bb.count]
    }
}
