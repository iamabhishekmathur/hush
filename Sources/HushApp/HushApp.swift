import SwiftUI
import AppKit

/// Menu-bar app (no dock icon). Owns the Ghost-Mode overlay, the live voice-sync
/// pipeline, and a script library/editor window.
@main
struct HushApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = ScriptStore()

    var body: some Scene {
        MenuBarExtra("Hush", systemImage: "text.viewfinder") {
            MenuContent(delegate: delegate, store: store)
        }

        Window("Hush — Scripts", id: "editor") {
            EditorView(store: store)
                .frame(minWidth: 680, minHeight: 440)
        }
        .windowResizability(.contentMinSize)

        Window("Calibrate Voice", id: "calibration") {
            CalibrationView()
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
        }
    }

    static let sampleScript = """
    Hi there. This is Hush — your script sits right at the camera, so you keep \
    eye contact while you present. It scrolls as you speak and waits when you \
    pause. And it stays invisible when you share your screen. Let's dive in.
    """
}

private struct MenuContent: View {
    @ObservedObject var delegate: AppDelegate
    @ObservedObject var store: ScriptStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if delegate.presenting {
            Button("Stop Prompter") { delegate.stop() }
        } else {
            Button("Start Prompter") {
                if let first = store.scripts.first { delegate.startPresenting(script: first.body) }
            }
            .disabled(store.scripts.first?.body.isEmpty ?? true)
        }

        Button(delegate.ghostOn ? "Ghost Mode: On (hidden when sharing)" : "Ghost Mode: Off (visible)") {
            delegate.toggleGhost()
        }

        Divider()
        Button("Edit Scripts…") { openWindow(id: "editor") }
        Button("Calibrate Voice…") { openWindow(id: "calibration") }
        SettingsLink { Text("Settings…") }

        Divider()
        Button("Quit Hush") { NSApplication.shared.terminate(nil) }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let overlay = OverlayWindowController()
    lazy var coordinator = PresentationCoordinator(model: overlay.model)

    @Published private(set) var ghostOn = true
    @Published private(set) var presenting = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // menu-bar agent, no dock icon
    }

    func startPresenting(script: String) {
        Task { @MainActor in
            guard await Permissions.requestMic() else { return }   // mic is required
            _ = await Permissions.requestSpeech()                  // speech optional (VAD fallback)
            overlay.show()
            overlay.setGhost(ghostOn)
            coordinator.start(script: script)
            presenting = true
        }
    }

    func stop() {
        coordinator.stop()
        overlay.hide()
        presenting = false
    }

    func toggleGhost() {
        ghostOn.toggle()
        overlay.setGhost(ghostOn)
    }
}
