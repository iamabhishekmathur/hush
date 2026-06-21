import Foundation

/// Which strategy is currently driving the scroll position.
public enum ScrollMode: String, Sendable {
    case voiceSynced   // anchored to a recognized-speech match
    case vadCreep      // no word match, but the user is speaking → creep forward
    case frozen        // silent / off-script → hold position
    case manual        // user took over with trackpad/keys
}

/// An original whitespace token of the script (surface form + layout position).
public struct Token: Equatable, Sendable {
    public let raw: String
    public let index: Int
    public var yOffset: Double
    public init(raw: String, index: Int, yOffset: Double) {
        self.raw = raw; self.index = index; self.yOffset = yOffset
    }
}

/// A single normalized *spoken-word* unit. Numbers/acronyms expand a single
/// surface token into several ScriptWords that all share the same `tokenIndex`
/// and `yOffset` (e.g. "$29" → twenty · nine · dollars). Matching happens in
/// spoken-word space; the engine reports position back in token space.
public struct ScriptWord: Equatable, Sendable {
    public let text: String        // normalized spoken form (lowercased)
    public let tokenIndex: Int     // originating script token
    public let yOffset: Double     // scroll offset of that token
    public let isDistinctive: Bool // content-bearing (not a stopword) → guards false jumps
    public init(text: String, tokenIndex: Int, yOffset: Double, isDistinctive: Bool) {
        self.text = text; self.tokenIndex = tokenIndex
        self.yOffset = yOffset; self.isDistinctive = isDistinctive
    }
}

/// A partial recognition result, mirroring what `SFSpeechRecognizer` emits.
public struct AsrResult: Sendable {
    public let timeMs: Int
    public let words: [String]    // recognized words so far (engine uses the tail)
    public let confidence: Double
    public init(timeMs: Int, words: [String], confidence: Double) {
        self.timeMs = timeMs; self.words = words; self.confidence = confidence
    }
}

/// Tunable parameters for the scroll-sync matcher. Defaults are the M0 baseline;
/// `test-plan.md` §4 defines the acceptance gates these feed.
public struct SyncConfig: Sendable {
    public var tail = 5            // # recognized words used to match
    public var back = 4           // search window behind the anchor
    public var ahead = 18         // search window ahead of the anchor
    public var minConfidence = 0.5 // accept threshold on normalized alignment score
    public var maxJumpWords = 14  // cap forward advance per accepted match
    public var matchScore = 2
    public var partialScore = 1
    public var mismatchScore = -1
    public var gapScore = -1
    public init() {}
}
