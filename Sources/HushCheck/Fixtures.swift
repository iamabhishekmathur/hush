import HushCore

/// Synthetic inputs a presenter would actually produce. Each ASR step carries
/// the `expectedToken` (ground truth: the script token the speaker is on), so
/// checks assert the engine's anchor tracks it. Mirrors docs/synthetic-data.md.
enum Fixtures {

    // MARK: scripts

    static let s1Sales = """
    Hi there. I'm going to show you how Hush keeps you looking at the \
    camera while you present. Watch the script scroll as I speak. When I \
    pause, it waits for me. Let's dive in.
    """

    static let s3Tech = """
    Our API handles 99.9% uptime. Pricing starts at $29, one time, no \
    subscription. The SDK ships for iOS and Android today, with a CLI for \
    power users.
    """

    // MARK: helper

    struct Step {
        let result: AsrResult
        let expectedToken: Int
    }
    static func step(_ t: Int, _ words: [String], _ conf: Double, _ exp: Int) -> Step {
        Step(result: AsrResult(timeMs: t, words: words, confidence: conf), expectedToken: exp)
    }

    // MARK: F-CLEAN — S1 read cleanly

    static let fClean: [Step] = [
        step( 300, ["hi"],                                              0.94,  0),
        step( 900, ["hi","there"],                                      0.93,  1),
        step(1700, ["there","i'm","going","to","show"],                 0.90,  5),
        step(2600, ["show","you","how","hush"],                         0.88,  8),
        step(3400, ["how","hush","keeps","you","looking"],              0.91, 11),
        step(4200, ["keeps","you","looking","at","the","camera"],       0.89, 14),
        step(5200, ["the","camera","while","you","present"],            0.90, 17),
        step(6100, ["watch","the","script"],                            0.92, 20),
        step(6900, ["the","script","scroll","as","i","speak"],          0.91, 24),
        step(8000, ["when","i","pause"],                                0.93, 27),
        step(8800, ["pause","it","waits","for","me"],                   0.90, 31),
        step(9700, ["let's","dive","in"],                               0.92, 34),
    ]

    // MARK: F-TECH — S3 with numbers/acronyms (stresses normalization)

    static let fTech: [Step] = [
        step( 400, ["our"],                                             0.92,  0),
        step(1100, ["our","a","p","i","handles"],                       0.86,  2),
        step(2200, ["handles","ninety","nine","point","nine","percent"],0.80,  3),
        step(3000, ["percent","uptime"],                                0.88,  4),
        step(3900, ["pricing","starts","at","twenty","nine","dollars"], 0.83,  8),
        step(4800, ["one","time","no","subscription"],                  0.87, 12),
        step(5700, ["the","s","d","k","ships"],                         0.84, 15),
        step(6600, ["for","i","o","s","and","android"],                 0.82, 19),
        step(7500, ["today","with","a","c","l","i"],                    0.80, 23),
        step(8300, ["for","power","users"],                             0.86, 26),
    ]

    // MARK: F-ADLIB — S1 with an off-script aside between idx 17 and 21

    static let fAdlib: [Step] = [
        step(5200, ["the","camera","while","you","present"],            0.90, 17),
        step(6000, ["and","honestly","this","changed","my","whole"],    0.84, 17), // off-script → hold
        step(6800, ["my","whole","workflow"],                           0.83, 17), // still off-script
        step(7600, ["watch","the","script","scroll"],                   0.91, 21), // re-sync
    ]
}
