import Foundation

/// Per-user voice profile derived from the onboarding calibration read.
public struct CalibrationProfile: Equatable, Sendable {
    public var noiseFloorDb: Double
    public var speakingDb: Double
    public var wordsPerMinute: Double

    public init(noiseFloorDb: Double, speakingDb: Double, wordsPerMinute: Double) {
        self.noiseFloorDb = noiseFloorDb
        self.speakingDb = speakingDb
        self.wordsPerMinute = wordsPerMinute
    }

    /// VAD threshold sits midway between the noise floor and speaking level.
    public var vadThreshold: Double { (noiseFloorDb + speakingDb) / 2 }

    /// Fallback creep speed in scroll units (≈ words) per second.
    public var creepVelocity: Double { wordsPerMinute / 60.0 }
}

public enum Calibration {
    /// Build a profile from a calibration read. Falls back to sane defaults if a
    /// section was too quiet/short to measure.
    public static func makeProfile(
        noiseSamplesDb: [Double],
        speechSamplesDb: [Double],
        spokenWords: Int,
        elapsedSeconds: Double
    ) -> CalibrationProfile {
        let noise = noiseSamplesDb.isEmpty ? -55 : noiseSamplesDb.reduce(0, +) / Double(noiseSamplesDb.count)
        let speech = speechSamplesDb.isEmpty ? -20 : speechSamplesDb.reduce(0, +) / Double(speechSamplesDb.count)
        let wpm = (elapsedSeconds > 0 && spokenWords > 0)
            ? Double(spokenWords) / elapsedSeconds * 60
            : 150
        return CalibrationProfile(noiseFloorDb: noise, speakingDb: speech, wordsPerMinute: wpm)
    }
}
