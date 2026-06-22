import AppKit
import SwiftUI

/// Owns the GhostPanel, positions it at camera level, and hosts the PrompterView
/// bound to a shared PrompterModel that the coordinator drives.
@MainActor
final class OverlayWindowController {
    let model = PrompterModel()

    private let panel: GhostPanel
    private let size = OverlayLayout.panelSize

    init() {
        let rect: CGRect
        if let screen = ScreenGeometry.targetScreen() {
            rect = ScreenGeometry.overlayFrame(on: screen, size: size)
        } else {
            rect = CGRect(x: 200, y: 200, width: size.width, height: size.height)
        }
        panel = GhostPanel(contentRect: rect)
        panel.contentView = NSHostingView(rootView: PrompterView(model: model))
    }

    func show() {
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
