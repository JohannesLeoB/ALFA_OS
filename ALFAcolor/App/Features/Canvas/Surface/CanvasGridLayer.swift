import SwiftUI
import AppTheme
import BoardModel

/// The dots of the background grid. They stay one device pixel group wide at every zoom.
struct CanvasGridLayer: View {
    /// The dots to draw. Empty while the grid is off.
    var dots: GridDots

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let side = 2 / displayScale
        let color = theme.color(.border, scheme)
        Canvas { context, _ in
            var path = Path()
            for x in dots.xs {
                for y in dots.ys {
                    path.addRect(CGRect(x: x - side / 2, y: y - side / 2, width: side, height: side))
                }
            }
            context.fill(path, with: .color(color))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
