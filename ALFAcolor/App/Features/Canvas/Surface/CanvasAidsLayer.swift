import SwiftUI
import AppTheme
import BoardModel

/// The aids on top of the items: frames around the selection, snap lines and measures.
/// Lines are one device pixel wide at every zoom. The layer takes no input.
struct CanvasAidsLayer: View {
    var controller: CanvasController

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let hairline = 1 / displayScale
        let selectionColor = theme.color(.accent, scheme)
        let snapColor = theme.color(.coral, scheme)
        let frames = controller.selectionFrames
        let snaps = controller.snapSegments
        let measures = controller.measureSegments
        Canvas { context, _ in
            for frame in frames {
                context.stroke(Path(CGRect(x: frame.x, y: frame.y, width: frame.w, height: frame.h)),
                               with: .color(selectionColor), lineWidth: hairline)
            }
            for segment in snaps {
                context.stroke(line(segment), with: .color(snapColor), lineWidth: hairline)
            }
            for (measure, segment) in measures {
                context.stroke(line(segment), with: .color(snapColor), lineWidth: hairline)
                let label = Text(measure.value, format: .number.precision(.fractionLength(0...1)))
                    .font(theme.text(.caption).font)
                    .foregroundStyle(snapColor)
                context.draw(label, at: CGPoint(x: (segment.fromX + segment.toX) / 2, y: (segment.fromY + segment.toY) / 2))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func line(_ segment: CanvasSegment) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: segment.fromX, y: segment.fromY))
        path.addLine(to: CGPoint(x: segment.toX, y: segment.toY))
        return path
    }
}
