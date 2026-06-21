import Foundation

/// Turns a script string into (a) layout tokens carrying scroll offsets and
/// (b) a flattened stream of normalized spoken words used for matching.
public struct Tokenizer {
    public let stopwords: Set<String>

    public init(stopwords: Set<String> = Tokenizer.defaultStopwords) {
        self.stopwords = stopwords
    }

    public static let defaultStopwords: Set<String> = [
        "the","a","an","and","of","to","in","is","it","at","for","as","with",
        "i","you","my","me","we","our","your","that","this","on","or","so",
        "i'm","let's","when","while","uh","um","like",
    ]

    /// In the test/headless layout each token is one scroll unit tall, so a
    /// token's `yOffset` equals its index — that makes "within ±N tokens"
    /// assertions in the test plan exact. The real app overwrites yOffset from
    /// the rendered text layout.
    public func tokenize(_ script: String) -> (tokens: [Token], words: [ScriptWord]) {
        let raw = script.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" || $0 == "\r" })
                        .map(String.init)
        var tokens: [Token] = []
        var words: [ScriptWord] = []
        for (i, surface) in raw.enumerated() {
            let yOffset = Double(i)
            tokens.append(Token(raw: surface, index: i, yOffset: yOffset))
            let expanded = Normalizer.expand(surface)
            let primary = expanded.first ?? ""
            let distinctive = !stopwords.contains(primary) && isContent(expanded)
            for w in expanded where !w.isEmpty {
                words.append(ScriptWord(text: w, tokenIndex: i, yOffset: yOffset, isDistinctive: distinctive))
            }
        }
        return (tokens, words)
    }

    /// Numbers/acronyms (multi-word expansions) are always content; otherwise
    /// require a word of length ≥ 4 so short fillers don't anchor false jumps.
    private func isContent(_ expanded: [String]) -> Bool {
        if expanded.count > 1 { return true }
        return (expanded.first?.count ?? 0) >= 4
    }
}
