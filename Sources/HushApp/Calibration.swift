import SwiftUI
import HushCore

/// Persisted voice profile (UserDefaults). Read by the coordinator to set the
/// VAD threshold and the fallback creep rate.
enum CalibrationStore {
    private static let noiseKey = "cal.noiseFloorDb"
    private static let speechKey = "cal.speakingDb"
    private static let wpmKey = "cal.wordsPerMinute"

    static func save(_ profile: CalibrationProfile) {
        let d = UserDefaults.standard
        d.set(profile.noiseFloorDb, forKey: noiseKey)
        d.set(profile.speakingDb, forKey: speechKey)
        d.set(profile.wordsPerMinute, forKey: wpmKey)
    }

    static func load() -> CalibrationProfile? {
        let d = UserDefaults.standard
        guard d.object(forKey: wpmKey) != nil else { return nil }
        return CalibrationProfile(noiseFloorDb: d.double(forKey: noiseKey),
                                  speakingDb: d.double(forKey: speechKey),
                                  wordsPerMinute: d.double(forKey: wpmKey))
    }
}

/// Drives the onboarding calibration: measure the room's noise floor, then time
/// a known passage to derive speaking level + words-per-minute.
@MainActor
final class CalibrationController: ObservableObject {
    enum Phase: Equatable { case idle, measuringNoise, readyToRead, reading, done }

    @Published var phase: Phase = .idle
    @Published var level: Double = 0

    static let passage = "The quick brown fox jumps over the lazy dog. " +
        "Pack my box with five dozen liquor jugs."
    private var passageWords: Int { Self.passage.split(separator: " ").count }

    private var mic: LiveMic?
    private let vad = VADEngine()
    private var noise: [Double] = []
    private var speech: [Double] = []
    private var lastMs: Int?
    private var readStartMs: Int?
    private var noiseTimer: Timer?

    func begin() {
        noise = []; speech = []; lastMs = nil; readStartMs = nil

        let mic = LiveMic()
        mic.onBuffer = { [weak self] db, ms in
            Task { @MainActor in self?.handle(db: db, ms: ms) }
        }
        self.mic = mic
        try? mic.start()

        phase = .measuringNoise
        noiseTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                if self?.phase == .measuringNoise { self?.phase = .readyToRead }
            }
        }
    }

    func startReading() {
        phase = .reading
        readStartMs = lastMs
    }

    func finish() {
        let elapsed = Double((lastMs ?? 0) - (readStartMs ?? 0)) / 1000.0
        mic?.stop(); mic = nil
        let profile = Calibration.makeProfile(noiseSamplesDb: noise,
                                              speechSamplesDb: speech,
                                              spokenWords: passageWords,
                                              elapsedSeconds: max(1, elapsed))
        CalibrationStore.save(profile)
        phase = .done
    }

    func cancel() {
        noiseTimer?.invalidate()
        mic?.stop(); mic = nil
        phase = .idle
    }

    private func handle(db: Double, ms: Int) {
        let dt = lastMs.map { Double(ms - $0) / 1000.0 } ?? 0.01
        lastMs = ms
        vad.update(dBFS: db, dt: max(0.001, min(0.5, dt)))
        level = vad.level
        switch phase {
        case .measuringNoise: noise.append(db)
        case .reading: speech.append(db)
        default: break
        }
    }
}

struct CalibrationView: View {
    @StateObject private var controller = CalibrationController()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Calibrate your voice").font(.title2.weight(.bold))

            ProgressView(value: controller.level)
                .frame(maxWidth: 320)

            Group {
                switch controller.phase {
                case .idle:
                    Text("Hush learns your voice so scrolling tracks how you actually speak.")
                        .multilineTextAlignment(.center)
                    Button("Begin") { controller.begin() }
                        .keyboardShortcut(.defaultAction)

                case .measuringNoise:
                    Text("Listening to the room — stay quiet for a moment…")
                        .foregroundStyle(.secondary)

                case .readyToRead:
                    Text(CalibrationController.passage)
                        .italic().multilineTextAlignment(.center)
                    Button("Start reading") { controller.startReading() }
                        .keyboardShortcut(.defaultAction)

                case .reading:
                    Text(CalibrationController.passage)
                        .multilineTextAlignment(.center)
                    Button("Done") { controller.finish() }
                        .keyboardShortcut(.defaultAction)

                case .done:
                    Label("Voice profile saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(width: 460)
        .padding(24)
        .onDisappear { controller.cancel() }
    }
}
