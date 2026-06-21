import AVFoundation
import Speech

/// Microphone + speech-recognition authorization. Hush degrades gracefully:
/// mic is required for any voice features; speech can be denied (the engine
/// falls back to VAD-only creep).
enum Permissions {
    static func requestMic() async -> Bool {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized { return true }
        return await withCheckedContinuation { cont in
            AVCaptureDevice.requestAccess(for: .audio) { cont.resume(returning: $0) }
        }
    }

    static func requestSpeech() async -> Bool {
        if SFSpeechRecognizer.authorizationStatus() == .authorized { return true }
        return await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
    }
}
