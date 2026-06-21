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

    /// Token-unit (≈ word) → point conversion for the scroll target.
    /// TODO(M2): replace the linear estimate with TextKit per-token measurement.
    private var pointsPerToken: CGFloat = 16

    init(model: PrompterModel) { self.model = model }

    // MARK: lifecycle

    func start(script: String, countdownSeconds: Int = 3) {
        let (_, words) = Tokenizer().tokenize(script)
        sync.load(words: words)
        sync.creepVelocity = 2.5            // ~150 wpm fallback when ASR has no match
        spring.snap(to: 0)
        lastBufferMs = nil
        model.scriptText = script
        model.scrollY = 0
        model.beamLevel = 0

        let mic = LiveMic()
        mic.onBuffer = { [weak self] db, ms in
            Task { @MainActor in self?.handleBuffer(db: db, ms: ms) }
        }
        mic.onResult = { [weak self] result in
            Task { @MainActor in self?.handleResult(result) }
        }
        self.mic = mic
        try? mic.start()

        beginCountdown(countdownSeconds)
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
        sync.tick(dt: 1.0 / 60.0, isSpeaking: vad.isSpeaking)
        let target = Double(CGFloat(sync.scrollTargetY) * pointsPerToken)
        spring.step(to: target, dt: 1.0 / 60.0)
        model.scrollY = CGFloat(spring.position)
    }
}
