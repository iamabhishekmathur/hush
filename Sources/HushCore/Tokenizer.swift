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

    /// Splits on whitespace while recording each token's UTF-16 range in the
    /// source string. In this headless layout each token is one scroll unit
    /// tall (yOffset == index), making "within ±N tokens" assertions exact; the
    /// app overwrites yOffset with measured point offsets from TextKit.
    public func tokenize(_ script: String) -> (tokens: [Token], words: [ScriptWord]) {
        var tokens: [Token] = []
        var words: [ScriptWord] = []

        var index = 0
        var u16 = 0           // running UTF-16 offset in the source
        var tokenStart = 0
        var current = ""

        func isWhitespace(_ s: Unicode.Scalar) -> Bool {
            s == " " || s == "\n" || s == "\t" || s == "\r"
        }

        func flush() {
            guard !current.isEmpty else { return }
            let i = index
            let yOffset = Double(i)
            tokens.append(Token(raw: current, index: i, yOffset: yOffset, utf16Range: tokenStart ..< u16))
            let expanded = Normalizer.expand(current)
            let primary = expanded.first ?? ""
            let distinctive = !stopwords.contains(primary) && isContent(expanded)
            for w in expanded where !w.isEmpty {
                words.append(ScriptWord(text: w, tokenIndex: i, yOffset: yOffset, isDistinctive: distinctive))
            }
            index += 1
            current = ""
        }

        for scalar in script.unicodeScalars {
            let width = scalar.utf16.count
            if isWhitespace(scalar) {
                flush()
            } else {
                if current.isEmpty { tokenStart = u16 }
                current.unicodeScalars.append(scalar)
            }
            u16 += width
        }
        flush()

        return (tokens, words)
    }

    /// Numbers/acronyms (multi-word expansions) are always content; otherwise
    /// require a word of length ≥ 4 so short fillers don't anchor false jumps.
    private func isContent(_ expanded: [String]) -> Bool {
        if expanded.count > 1 { return true }
        return (expanded.first?.count ?? 0) >= 4
    }
}
