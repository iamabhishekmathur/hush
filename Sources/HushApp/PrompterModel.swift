import SwiftUI

/// Observable state the overlay renders. The PresentationCoordinator writes to
/// it each frame; PrompterView reads it.
@MainActor
final class PrompterModel: ObservableObject {
    @Published var scriptText: String = ""
    @Published var scrollY: CGFloat = 0      // points the text is scrolled up by
    @Published var beamLevel: Double = 0     // 0...1 volume beam
    @Published var fontSize: CGFloat = 30
    @Published var countdown: Int? = nil     // non-nil during the pre-roll
}
