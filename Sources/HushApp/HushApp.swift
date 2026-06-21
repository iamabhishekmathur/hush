import SwiftUI
import AppKit

/// M0 app shell: a menu-bar-only app (no dock icon) that shows the Ghost-Mode
/// notch overlay and toggles its capture visibility. Script library, editor,
/// onboarding, and the live voice-sync pipeline arrive in later milestones.
@main
struct HushApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("Hush", systemImage: "text.viewfinder") {
            Button("Show Prompter") { delegate.showPrompter() }
            Button(delegate.ghostOn ? "Ghost Mode: On" : "Ghost Mode: Off") {
                delegate.toggleGhost()
            }
            Divider()
            Button("Quit Hush") { NSApplication.shared.terminate(nil) }
        }
    }

    static let sampleScript = """
    Hi there. This is Hush — your script sits right at the camera, so you keep \
    eye contact while you present. It scrolls as you speak and waits when you \
    pause. And it stays invisible when you share your screen.
    """
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var overlay: OverlayWindowController?
    @Published private(set) var ghostOn = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // menu-bar app, no dock icon
    }

    func showPrompter() {
        let controller = overlay ?? OverlayWindowController()
        overlay = controller
        controller.show(scriptText: HushApp.sampleScript)
        controller.setGhost(ghostOn)
    }

    func toggleGhost() {
        ghostOn.toggle()
        overlay?.setGhost(ghostOn)
    }
}
