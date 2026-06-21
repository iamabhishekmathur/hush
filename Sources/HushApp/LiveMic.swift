import AVFoundation
import Speech
import HushCore

/// One microphone stream feeding BOTH voice-activity energy (`AudioSource`) and
/// on-device speech recognition (`SpeechSource`). A single `AVAudioEngine` with
/// a single tap fans out to dBFS for the VAD and audio buffers for the ASR,
/// matching the spec's "one mic stream feeds both" requirement.
final class LiveMic: AudioSource, SpeechSource {
    var onBuffer: ((_ dBFS: Double, _ timeMs: Int) -> Void)?
    var onResult: ((AsrResult) -> Void)?

    private let engine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func start() throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer?.supportsOnDeviceRecognition == true {
            req.requiresOnDeviceRecognition = true   // privacy: never leaves the Mac
        }
        request = req

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            guard let self else { return }
            self.request?.append(buffer)
            let db = LiveMic.dBFS(buffer)
            let ms = format.sampleRate > 0 ? Int(Double(time.sampleTime) / format.sampleRate * 1000) : 0
            self.onBuffer?(db, ms)
        }

        engine.prepare()
        try engine.start()

        task = recognizer?.recognitionTask(with: req) { [weak self] result, _ in
            guard let self, let result else { return }
            let words = result.bestTranscription.formattedString
                .lowercased()
                .split(whereSeparator: { $0 == " " || $0 == "\n" })
                .map(String.init)
            let ms = Int((result.bestTranscription.segments.last?.timestamp ?? 0) * 1000)
            self.onResult?(AsrResult(timeMs: ms, words: words, confidence: 1))
        }
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
    }

    /// RMS energy of a buffer in dBFS (−160 if empty).
    static func dBFS(_ buffer: AVAudioPCMBuffer) -> Double {
        guard let channel = buffer.floatChannelData?[0] else { return -160 }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return -160 }
        var sum: Float = 0
        for i in 0..<n { let s = channel[i]; sum += s * s }
        let rms = (sum / Float(n)).squareRoot()
        return Double(20 * log10(max(rms, 1e-7)))
    }
}
