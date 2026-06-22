import AppKit
import HushCore

/// Wires the live pipeline: LiveMic → VADEngine + ScrollSyncEngine → SpringScroller
/// → PrompterModel. Runs the countdown, a 60 fps scroll tick, and start/pause/stop.
@MainActor
final class PresentationCoordinator {
    enum State: Equatable { case idle, countdown, presenting, paused }
    private(set) var state: State = .idle

    let model: PrompterModel

    private let sync = ScrollSyncEngine()
    private let vad = VADEngine()
    private var spring = SpringScroller(omega: 14)
    private var mic: LiveMic?

    private var ticker: Timer?
    private var countdownTimer: Timer?
    private var lastBufferMs: Int?
    private var voiceSyncEnabled = true

    init(model: PrompterModel) { self.model = model }

    // MARK: lifecycle

    func start(script: String) {
        let d = UserDefaults.standard
        let fontSize = (d.object(forKey: SettingsKey.fontSize) as? Double) ?? 30
        let countdown = (d.object(forKey: SettingsKey.countdown) as? Int) ?? 3
        voiceSyncEnabled = (d.object(forKey: SettingsKey.voiceSync) as? Bool) ?? true
        let sensitivity = (d.object(forKey: SettingsKey.micSensitivity) as? Double) ?? 0

        model.fontSize = CGFloat(fontSize)

        // Measure real per-token scroll offsets at the exact render font/width.
        let font = ScriptLayout.prompterFont(size: CGFloat(fontSize))
        let (words, pointsPerWord) = ScriptLayout.measuredWords(
            text: script, font: font, width: OverlayLayout.textWidth)
        sync.load(words: words)
        sync.readingLineOffset = OverlayLayout.readingLineY

        let profile = CalibrationStore.load()
        let wpm = profile?.wordsPerMinute ?? 150
        sync.creepVelocity = wpm / 60.0 * pointsPerWord          // points/second
        vad.threshold = (profile?.vadThreshold ?? -35) - sensitivity

        spring.snap(to: 0)
        lastBufferMs = nil
        model.scriptText = script
        model.scrollY = 0
        model.beamLevel = 0

        if voiceSyncEnabled {
            let mic = LiveMic()
            mic.onBuffer = { [weak self] db, ms in
                Task { @MainActor in self?.handleBuffer(db: db, ms: ms) }
            }
            mic.onResult = { [weak self] result in
                Task { @MainActor in self?.handleResult(result) }
            }
            self.mic = mic
            try? mic.start()
        } else {
            sync.beginAutoScroll()                               // steady auto-scroll
        }

        beginCountdown(countdown)
    }

    func pause() { if state == .presenting { state = .paused } }
    func resume() { if state == .paused { state = .presenting } }

    func stop() {
        ticker?.invalidate(); ticker = nil
        countdownTimer?.invalidate(); countdownTimer = nil
        mic?.stop(); mic = nil
        vad.reset()
        state = .idle
        model.countdown = nil
        model.beamLevel = 0
    }

    // MARK: countdown → present

    private func beginCountdown(_ seconds: Int) {
        state = .countdown
        guard seconds > 0 else { beginPresenting(); return }
        model.countdown = seconds
        // Timer blocks fire on the main run loop, so we are already on the main
        // actor — assumeIsolated avoids a task hop and the Sendable-capture trap.
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { timer.invalidate(); return }
                let next = (self.model.countdown ?? 1) - 1
                if next <= 0 {
                    timer.invalidate()
                    self.model.countdown = nil
                    self.beginPresenting()
                } else {
                    self.model.countdown = next
                }
            }
        }
    }

    private func beginPresenting() {
        state = .presenting
        ticker = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    // MARK: callbacks

    private func handleBuffer(db: Double, ms: Int) {
        let dt = lastBufferMs.map { Double(ms - $0) / 1000.0 } ?? 0.01
        lastBufferMs = ms
        vad.update(dBFS: db, dt: max(0.001, min(0.5, dt)))
        model.beamLevel = vad.level
    }

    private func handleResult(_ result: AsrResult) {
        guard state == .presenting else { return }
        sync.ingest(result, isSpeaking: vad.isSpeaking)
    }

    private func tick() {
        guard state == .presenting else { return }
        // scrollTargetY is already in points (measured layout); spring eases to it.
        sync.tick(dt: 1.0 / 60.0, isSpeaking: voiceSyncEnabled ? vad.isSpeaking : true)
        spring.step(to: sync.scrollTargetY, dt: 1.0 / 60.0)
        model.scrollY = CGFloat(spring.position)
    }
}
