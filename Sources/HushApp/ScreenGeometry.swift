import AppKit

/// Notch / multi-display geometry for placing the overlay at camera level.
enum ScreenGeometry {

    /// Screen to host the overlay (defaults to the one with the menu bar).
    static func targetScreen(preferred: NSScreen? = nil) -> NSScreen? {
        preferred ?? NSScreen.main ?? NSScreen.screens.first
    }

    /// Whether the screen has a camera notch (non-zero top safe-area inset).
    static func hasNotch(_ screen: NSScreen) -> Bool {
        if #available(macOS 12.0, *) { return screen.safeAreaInsets.top > 0 }
        return false
    }

    /// Frame to place a prompter of `size`, centered under the notch if present,
    /// otherwise top-center just below the menu bar. AppKit y grows upward.
    static func overlayFrame(on screen: NSScreen, size: CGSize, topMargin: CGFloat = 8) -> CGRect {
        let f = screen.frame
        let x = f.midX - size.width / 2
        let topInset: CGFloat = {
            if #available(macOS 12.0, *) { return screen.safeAreaInsets.top }
            return 0
        }()
        let y = f.maxY - size.height - max(topInset, topMargin)
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }
}
