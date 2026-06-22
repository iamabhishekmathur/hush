import CoreGraphics

/// Single source of truth for the overlay's geometry, shared by the window, the
/// SwiftUI rendering, and the TextKit measurement so scroll offsets line up.
enum OverlayLayout {
    static let panelSize = CGSize(width: 600, height: 150)
    static let textHorizontalPadding: CGFloat = 24
    static var textWidth: CGFloat { panelSize.width - textHorizontalPadding * 2 }
    /// Points from the top of the panel where the current line sits.
    static let readingLineY: Double = 46
}
