import Foundation
import HushCore

// Hush core self-test. Replays the synthetic fixtures through the pure engines
// and asserts the acceptance gates from docs/test-plan.md §4.
// Run: swift run HushCheck

let h = Harness()
let cfg = SyncConfig()

func loaded(_ script: String) -> ScrollSyncEngine {
    let (_, words) = Tokenizer().tokenize(script)
    let e = ScrollSyncEngine()
    e.load(words: words)
    return e
}

/// % of steps whose anchor lands within ±tolerance tokens of ground truth.
func accuracy(_ engine: ScrollSyncEngine, _ steps: [Fixtures.Step], tolerance: Int) -> Double {
    var within = 0
    for s in steps {
        engine.ingest(s.result)
        if abs(engine.anchorTokenIndex - s.expectedToken) <= tolerance { within += 1 }
    }
    return Double(within) / Double(steps.count)
}

// MARK: Normalizer

h.suite("Normalizer") {
    h.equal(Normalizer.expand("$29"), ["twenty","nine","dollars"], "currency $29")
    h.equal(Normalizer.expand("$1"), ["one","dollar"], "singular dollar")
    h.equal(Normalizer.expand("99.9%"), ["ninety","nine","point","nine","percent"], "percent 99.9%")
    h.equal(Normalizer.expand("50%"), ["fifty","percent"], "percent 50%")
    h.equal(Normalizer.expand("10"), ["ten"], "bare number 10")
    h.equal(Normalizer.expand("21"), ["twenty","one"], "bare number 21")
    h.equal(Normalizer.expand("API"), ["a","p","i"], "acronym API")
    h.equal(Normalizer.expand("SDK"), ["s","d","k"], "acronym SDK")
    h.equal(Normalizer.expand("iOS"), ["i","o","s"], "acronym iOS")
    h.equal(Normalizer.expand("Hush"), ["hush"], "plain word")
    h.equal(Normalizer.expand("present."), ["present"], "trailing punctuation")
    h.equal(Normalizer.expand("..."), [], "punctuation-only is empty")
}

// MARK: Tokenizer

h.suite("Tokenizer") {
    let (tokens, words) = Tokenizer().tokenize(Fixtures.s1Sales)
    h.equal(tokens.count, 35, "S1 token count")
    h.equal(words.count, 35, "S1 word count (no expansions)")

    let (_, tech) = Tokenizer().tokenize(Fixtures.s3Tech)
    h.equal(tech.filter { $0.tokenIndex == 1 }.map(\.text), ["a","p","i"], "API expands to token 1")
    h.equal(tech.filter { $0.tokenIndex == 8 }.map(\.text), ["twenty","nine","dollars"], "$29 expands to token 8")

    let (_, cw) = Tokenizer().tokenize("the camera")
    h.equal(cw.first { $0.text == "the" }?.isDistinctive, false, "'the' is not distinctive")
    h.equal(cw.first { $0.text == "camera" }?.isDistinctive, true, "'camera' is distinctive")
}

// MARK: Alignment

h.suite("Alignment") {
    let win = ["watch","the","script","scroll","as"]
    let (end, score) = Alignment.bestLocalAlignment(tail: ["script","scroll"], window: win, config: cfg)
    h.equal(end, 3, "exact tail ends at 'scroll'")
    h.approx(score, 1.0, 0.001, "exact tail scores 1.0")

    let (_, drift) = Alignment.bestLocalAlignment(tail: ["script","scrawl"], window: ["the","script","scroll"], config: cfg)
    h.gt(drift, 0.5, "ASR drift 'scrawl'~'scroll' still scores")

    let (_, none) = Alignment.bestLocalAlignment(tail: ["completely","unrelated"], window: win, config: cfg)
    h.le(none, 0.5, "no match scores low")

    h.equal(Alignment.sim("a", "p", cfg), cfg.mismatchScore, "single letters require exact")
    h.equal(Alignment.sim("a", "a", cfg), cfg.matchScore, "single letter exact match")
}

// MARK: VAD

h.suite("VAD") {
    let vad = VADEngine(threshold: -35, attack: 0.08, release: 0.6)
    h.check(!vad.isSpeaking, "starts silent")
    for _ in 0..<15 { vad.update(dBFS: -20, dt: 0.01) }
    h.check(vad.isSpeaking, "detects speech after attack")
    for _ in 0..<59 { vad.update(dBFS: -55, dt: 0.01) }
    h.check(vad.isSpeaking, "still speaking at 590 ms of silence")
    for _ in 0..<3 { vad.update(dBFS: -55, dt: 0.01) }
    h.check(!vad.isSpeaking, "silence clears within 600 ms")

    let loud = VADEngine()
    for _ in 0..<50 { loud.update(dBFS: -6, dt: 0.02) }
    h.gt(loud.level, 0.7, "level tracks loudness")
}

// MARK: ScrollSyncEngine — the core gates

h.suite("ScrollSync · clean read (gate ≥0.92)") {
    let e = loaded(Fixtures.s1Sales)
    let acc = accuracy(e, Fixtures.fClean, tolerance: 3)
    h.ge(acc, 0.92, "clean-read accuracy within ±3 tokens")
    h.ge(e.anchorTokenIndex, 33, "reached end of script")
}

h.suite("ScrollSync · monotonic on clean read") {
    let e = loaded(Fixtures.s1Sales)
    var last = -1
    var monotonic = true
    for s in Fixtures.fClean {
        e.ingest(s.result)
        if e.anchorTokenIndex < last { monotonic = false }
        last = e.anchorTokenIndex
    }
    h.check(monotonic, "anchor never moves backward on a clean read")
}

h.suite("ScrollSync · numbers & acronyms (gate ≥0.85)") {
    let e = loaded(Fixtures.s3Tech)
    let acc = accuracy(e, Fixtures.fTech, tolerance: 3)
    h.ge(acc, 0.85, "tech accuracy within ±3 tokens")
    h.ge(e.anchorTokenIndex, 24, "tracked through to the CLI line")
}

h.suite("ScrollSync · ad-lib hold then re-sync") {
    let e = loaded(Fixtures.s1Sales)
    // An ad-lib happens mid-presentation: lead in with the clean read so the
    // engine genuinely sits on "present" (token 17) before the aside.
    for s in Fixtures.fClean.prefix(7) { e.ingest(s.result) }
    h.equal(e.anchorTokenIndex, 17, "anchored at 'present' after clean lead-in")
    var anchors: [Int] = []
    for s in Fixtures.fAdlib[1...] { e.ingest(s.result); anchors.append(e.anchorTokenIndex) }
    h.le(anchors[0], 18, "held during off-script aside")
    h.le(anchors[1], 18, "still held during aside")
    h.ge(anchors[2], 20, "re-synced after returning to script")
}

h.suite("ScrollSync · off-script enters VAD mode") {
    let e = loaded(Fixtures.s1Sales)
    e.ingest(Fixtures.fClean[6].result)
    let mode = e.ingest(AsrResult(timeMs: 0, words: ["totally","unscripted","tangent"], confidence: 0.8), isSpeaking: true)
    h.equal(mode, .vadCreep, "no word match while speaking → vadCreep")
}

h.suite("ScrollSync · creep stops on silence (no runaway)") {
    let e = loaded(Fixtures.s1Sales)
    e.creepVelocity = 5
    _ = e.ingest(AsrResult(timeMs: 0, words: ["totally","unscripted"], confidence: 0.8), isSpeaking: true)
    h.equal(e.mode, .vadCreep, "entered creep")
    let before = e.scrollTargetY
    e.tick(dt: 0.1, isSpeaking: true)
    h.gt(e.scrollTargetY, before, "creeps while speaking")
    let mid = e.scrollTargetY
    e.tick(dt: 0.1, isSpeaking: false)
    h.equal(e.mode, .frozen, "freezes on silence")
    e.tick(dt: 0.1, isSpeaking: false)
    h.equal(e.scrollTargetY, mid, "no scroll movement during silence")
}

h.suite("ScrollSync · manual override re-anchors") {
    let e = loaded(Fixtures.s1Sales)
    e.manualScroll(toTokenIndex: 20)
    h.equal(e.anchorTokenIndex, 20, "anchored to token 20")
    h.equal(e.mode, .manual, "mode is manual")
}

exit(Int32(h.summarize()))
