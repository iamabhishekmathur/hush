import SwiftUI

/// Minimal teleprompter rendering for M0: the script over a translucent panel,
/// vertically offset by the scroll position, with a volume beam and a faint
/// reading-line indicator. Per-word highlighting and live editing come in M1.
struct PrompterView: View {
    let scriptText: String
    var scrollY: CGFloat          // in points; driven by ScrollSyncEngine
    var beamLevel: Double         // 0...1 from VADEngine
    var fontSize: CGFloat = 28

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.55))

            Text(scriptText)
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .offset(y: 44 - scrollY)

            // reading-line indicator
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)
                    .padding(.top, 40)
                Spacer()
            }

            // volume beam
            VStack {
                Spacer()
                Capsule()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: max(8, 140 * beamLevel), height: 3)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
