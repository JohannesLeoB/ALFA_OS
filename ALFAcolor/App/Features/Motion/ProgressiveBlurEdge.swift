import SwiftUI
import AppTheme
import Motion

/// A band of blur that fades downward from its top edge, built from the layers of `BlurRamp`.
/// With reduced transparency the band is a calm surface that fades out instead of blurring.
struct ProgressiveBlurEdge: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            if reduceTransparency {
                Rectangle()
                    .fill(theme.color(.surface, scheme))
                    .mask(fade(to: 1))
            } else {
                ForEach(BlurRamp.ends(), id: \.self) { end in
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .mask(fade(to: end))
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// Opaque at the top edge and clear at `end` of the band height. The colours only set the mask's alpha.
    private func fade(to end: Double) -> LinearGradient {
        LinearGradient(colors: [.white, .clear],
                       startPoint: .top,
                       endPoint: UnitPoint(x: 0.5, y: CGFloat(end)))
    }
}
