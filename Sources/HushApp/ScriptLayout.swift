import AppKit
import HushCore

/// Measures where each script token actually lands when rendered, using TextKit,
/// so the scroll position reflects real wrapped layout instead of a linear
/// token→pixel estimate. The measured point offsets are written into the engine
/// words' `yOffset`.
enum ScriptLayout {

    static func prompterFont(size: CGFloat) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: .semibold)
        if let descriptor = base.fontDescriptor.withDesign(.rounded) {
            return NSFont(descriptor: descriptor, size: size) ?? base
        }
        return base
    }

    /// Top y (points) of each token when laid out at `width` with `font`.
    static func tokenYOffsets(text: String, tokens: [Token], font: NSFont, width: CGFloat) -> [Double] {
        let storage = NSTextStorage(string: text, attributes: [.font: font])
        let manager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        manager.ensureLayout(for: container)

        return tokens.map { token in
            let nsRange = NSRange(location: token.utf16Range.lowerBound, length: token.utf16Range.count)
            let glyphRange = manager.glyphRange(forCharacterRange: nsRange, actualCharacterRange: nil)
            return Double(manager.boundingRect(forGlyphRange: glyphRange, in: container).minY)
        }
    }

    /// Engine words with measured point offsets, plus avg points-per-word
    /// (used to translate a words-per-minute creep rate into points/second).
    static func measuredWords(text: String, font: NSFont, width: CGFloat) -> (words: [ScriptWord], pointsPerWord: Double) {
        let (tokens, words) = Tokenizer().tokenize(text)
        guard !tokens.isEmpty, !words.isEmpty else { return ([], 16) }

        let ys = tokenYOffsets(text: text, tokens: tokens, font: font, width: width)
        let measured = words.map { w in
            ScriptWord(text: w.text,
                       tokenIndex: w.tokenIndex,
                       yOffset: w.tokenIndex < ys.count ? ys[w.tokenIndex] : w.yOffset,
                       isDistinctive: w.isDistinctive)
        }
        let contentHeight = (ys.max() ?? 0) + Double(font.boundingRectForFont.height)
        return (measured, contentHeight / Double(words.count))
    }
}
