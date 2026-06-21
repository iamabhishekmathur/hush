import SwiftUI

/// The teleprompter overlay: script over a translucent panel, scrolled by the
/// model's `scrollY`, with a reading-line indicator, a volume beam, and the
/// pre-roll countdown. Per-word highlighting comes in a later milestone.
struct PrompterView: View {
    @ObservedObject var model: PrompterModel

    private let readingLineY: CGFloat = 46

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.55))

            Text(model.scriptText)
                .font(.system(size: model.fontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .offset(y: readingLineY + 4 - model.scrollY)

            // reading-line indicator
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)
                    .padding(.top, readingLineY)
                Spacer()
            }

            // volume beam
            VStack {
                Spacer()
                Capsule()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: max(8, 160 * model.beamLevel), height: 3)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)

            // pre-roll countdown
            if let count = model.countdown {
                Text("\(count)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.35))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
