import AppKit
import SwiftUI

/// Owns the GhostPanel and positions it at camera level. Hosts the SwiftUI
/// PrompterView. M0 wires display/placement/Ghost Mode; the audio→sync→scroll
/// pipeline (HushCore) lands in M1.
@MainActor
final class OverlayWindowController {
    private let panel: GhostPanel
    private let size: CGSize

    init(size: CGSize = CGSize(width: 560, height: 130)) {
        self.size = size
        let screen = ScreenGeometry.targetScreen() ?? NSScreen.main!
        let frame = ScreenGeometry.overlayFrame(on: screen, size: size)
        panel = GhostPanel(contentRect: frame)
    }

    func show(scriptText: String) {
        let host = NSHostingView(rootView: PrompterView(scriptText: scriptText, scrollY: 0, beamLevel: 0))
        panel.contentView = host
        reposition()
        panel.orderFrontRegardless()
    }

    func reposition() {
        guard let screen = ScreenGeometry.targetScreen() else { return }
        panel.setFrame(ScreenGeometry.overlayFrame(on: screen, size: size), display: true)
    }

    func setGhost(_ on: Bool) { panel.setGhost(on) }
    func hide() { panel.orderOut(nil) }
}
