import Foundation

/// Microphone energy source. The live implementation (AVAudioEngine tap) lives
/// in the app target; tests inject a mock that replays a fixture. Keeping this a
/// protocol is what lets `HushCore` stay free of AVFoundation.
public protocol AudioSource: AnyObject {
    /// Called per audio hop with the buffer's energy in dBFS and a timestamp (ms).
    var onBuffer: ((_ dBFS: Double, _ timeMs: Int) -> Void)? { get set }
    func start() throws
    func stop()
}

/// Speech recognition source. Live = `SFSpeechRecognizer` (on-device); tests
/// inject a mock that emits a scripted stream of `AsrResult`s on a virtual clock.
public protocol SpeechSource: AnyObject {
    var onResult: ((AsrResult) -> Void)? { get set }
    func start() throws
    func stop()
}
