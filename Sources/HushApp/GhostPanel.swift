import AppKit

/// A borderless, non-activating floating panel that:
///  - never steals focus from the app you're presenting from,
///  - floats above full-screen apps and shows on every Space,
///  - is excluded from screen capture / screenshots when Ghost Mode is on.
///
/// Ghost Mode is the whole trick: `sharingType = .none` removes the window from
/// ScreenCaptureKit / CGWindowList output, so Zoom/Teams/Meet/Loom/OBS and the
/// macOS screenshot tools never see it — while it stays visible on your display.
final class GhostPanel: NSPanel {

    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.nonactivatingPanel, .borderless, .resizable],
                   backing: .buffered,
                   defer: false)

        isFloatingPanel = true
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        setGhost(true)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// ON = invisible to screen capture/recording/screenshots; OFF = visible.
    func setGhost(_ on: Bool) {
        sharingType = on ? .none : .readOnly
    }
}
