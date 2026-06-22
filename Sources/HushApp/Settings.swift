import SwiftUI

enum SettingsKey {
    static let fontSize = "fontSize"
    static let countdown = "countdownSeconds"
    static let voiceSync = "voiceSyncEnabled"
    static let micSensitivity = "micSensitivityDb"
}

/// Standard Settings window (⌘,). Values persist in UserDefaults and are read by
/// the PresentationCoordinator at the start of each session.
struct SettingsView: View {
    @AppStorage(SettingsKey.fontSize) private var fontSize = 30.0
    @AppStorage(SettingsKey.countdown) private var countdown = 3
    @AppStorage(SettingsKey.voiceSync) private var voiceSync = true
    @AppStorage(SettingsKey.micSensitivity) private var micSensitivity = 0.0

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Form {
            Section("Appearance") {
                Slider(value: $fontSize, in: 18...60, step: 1) {
                    Text("Text size")
                } minimumValueLabel: {
                    Text("A").font(.caption)
                } maximumValueLabel: {
                    Text("A").font(.title3)
                }
                Text("\(Int(fontSize)) pt").foregroundStyle(.secondary)
            }

            Section("Presentation") {
                Stepper("Countdown: \(countdown)s", value: $countdown, in: 0...10)
                Toggle("Voice-synced scrolling", isOn: $voiceSync)
                if !voiceSync {
                    Text("Off: the script auto-scrolls at a steady pace.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Voice") {
                Slider(value: $micSensitivity, in: -12...12, step: 1) { Text("Mic sensitivity") }
                Text(String(format: "%+.0f dB", micSensitivity)).foregroundStyle(.secondary)
                Button("Recalibrate voice…") { openWindow(id: "calibration") }
                    .disabled(!voiceSync)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding(.vertical, 8)
    }
}
