import Foundation

/// Voice-activity detection from audio energy. Decides `isSpeaking` with
/// attack/release hysteresis and produces a smoothed `level` (0...1) for the
/// volume beam. Pure: fed dBFS samples + dt, no AVFoundation here.
public final class VADEngine {
    public var threshold: Double      // dBFS; below = silence
    public let attack: Double         // seconds above threshold before "speaking"
    public let release: Double        // seconds below threshold before "silent"

    public private(set) var isSpeaking = false
    public private(set) var level: Double = 0

    private var aboveTime = 0.0
    private var belowTime = 0.0

    /// `release` defaults to 0.6 s to satisfy the "silence → velocity 0 ≤ 600 ms" gate.
    public init(threshold: Double = -35, attack: Double = 0.08, release: Double = 0.6) {
        self.threshold = threshold
        self.attack = attack
        self.release = release
    }

    public func update(dBFS: Double, dt: Double) {
        if dBFS > threshold {
            aboveTime += dt; belowTime = 0
            if aboveTime >= attack { isSpeaking = true }
        } else {
            belowTime += dt; aboveTime = 0
            if belowTime >= release { isSpeaking = false }
        }
        let target = max(0, min(1, (dBFS + 60) / 60))   // map -60...0 dBFS → 0...1
        let k = min(1, dt / 0.1)
        level += (target - level) * k
    }

    public func reset() {
        isSpeaking = false; level = 0; aboveTime = 0; belowTime = 0
    }
}
