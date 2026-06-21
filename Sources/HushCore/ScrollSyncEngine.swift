import Foundation

/// The core of Hush. Consumes ASR partials + a speaking flag and produces a
/// target scroll position (in token space and in y-offset). Pure and
/// synchronous so the whole behavior is deterministically testable via the
/// fixture-replay harness (see Tests/HushCoreTests).
public final class ScrollSyncEngine {
    public private(set) var words: [ScriptWord] = []
    public private(set) var anchorWord: Int = 0
    public private(set) var mode: ScrollMode = .frozen
    public private(set) var scrollTargetY: Double = 0

    public var config: SyncConfig
    public var creepVelocity: Double = 0      // yOffset units / second (from calibration)
    public let readingLineOffset: Double

    private var pendingBackward = 0

    public init(config: SyncConfig = SyncConfig(), readingLineOffset: Double = 0) {
        self.config = config
        self.readingLineOffset = readingLineOffset
    }

    public func load(words: [ScriptWord]) {
        self.words = words
        anchorWord = 0
        pendingBackward = 0
        mode = .frozen
        scrollTargetY = (words.first?.yOffset ?? 0) - readingLineOffset
    }

    /// Current position reported in script-token space.
    public var anchorTokenIndex: Int {
        words.isEmpty ? 0 : words[min(anchorWord, words.count - 1)].tokenIndex
    }

    /// Feed one recognition partial. Returns the resulting mode.
    @discardableResult
    public func ingest(_ result: AsrResult, isSpeaking: Bool = true) -> ScrollMode {
        guard !words.isEmpty else { return mode }
        let tail = result.words.suffix(config.tail).map { $0.lowercased() }
        guard !tail.isEmpty else { return updateForVAD(isSpeaking) }

        let lo = max(0, anchorWord - config.back)
        let hi = min(words.count - 1, anchorWord + config.ahead)
        guard lo <= hi else { return mode }

        let windowWords = words[lo...hi].map(\.text)
        let (endIdx, score) = Alignment.bestLocalAlignment(tail: Array(tail), window: windowWords, config: config)
        guard endIdx >= 0, score >= config.minConfidence else { return updateForVAD(isSpeaking) }

        var candidate = lo + endIdx
        let delta = candidate - anchorWord

        // Large backward correction needs two consecutive confirmations
        // (handles a restarted line without oscillating).
        if delta < -2 {
            pendingBackward += 1
            if pendingBackward < 2 { return mode }
        } else {
            pendingBackward = 0
        }

        // Cap a single forward advance so a far match catches up over a few ticks.
        if delta > config.maxJumpWords { candidate = anchorWord + config.maxJumpWords }

        // A forward jump must cross at least one distinctive word — rejects
        // false jumps that latch onto repeated common words ("the", "and").
        if delta > 2 {
            let spanLo = min(anchorWord, candidate)
            let spanHi = min(max(anchorWord, candidate), words.count - 1)
            let crossesDistinctive = (spanLo...spanHi).contains { words[$0].isDistinctive }
            if !crossesDistinctive { return mode }
        }

        anchorWord = max(0, min(candidate, words.count - 1))
        scrollTargetY = words[anchorWord].yOffset - readingLineOffset
        mode = .voiceSynced
        return mode
    }

    /// Advance the scroll target while the user is speaking but no word match is
    /// available (VAD creep). Frozen on silence — no runaway.
    public func tick(dt: Double, isSpeaking: Bool) {
        switch mode {
        case .vadCreep:
            if isSpeaking { scrollTargetY += creepVelocity * dt }
            else { mode = .frozen }
        default:
            break
        }
    }

    /// User scrubbed manually; re-anchor to the nearest word at/after a token.
    public func manualScroll(toTokenIndex tokenIndex: Int) {
        if let w = words.firstIndex(where: { $0.tokenIndex >= tokenIndex }) {
            anchorWord = w
            scrollTargetY = words[w].yOffset - readingLineOffset
        }
        mode = .manual
    }

    private func updateForVAD(_ isSpeaking: Bool) -> ScrollMode {
        mode = isSpeaking ? .vadCreep : .frozen
        return mode
    }
}
