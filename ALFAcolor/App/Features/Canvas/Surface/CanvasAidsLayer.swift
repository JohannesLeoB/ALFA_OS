import SwiftUI
import AppTheme
import BoardModel

/// The aids on top of the items: snap lines and measures, in the coral color, one point wide at every zoom.
/// The frames around the selection and the handles are in `SelectionLayer`. The layer takes no input.
struct CanvasAidsLayer: View {
    var controller: CanvasController
    var interaction: CanvasInteraction

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let snapColor = theme.color(.coral, scheme)
        let snaps = controller.snapSegments
        let measures = controller.measureSegments
        let labels = interaction.distanceLabels
        Canvas { context, _ in
            for segment in snaps {
                context.stroke(line(segment), with: .color(snapColor), lineWidth: SelectionStyle.lineWidth)
            }
            for (index, entry) in measures.enumerated() {
                context.stroke(line(entry.segment), with: .color(snapColor), lineWidth: SelectionStyle.lineWidth)
                let label = labelText(labels.indices.contains(index) ? labels[index] : nil, fallback: entry.measure.value)
                    .font(theme.text(.caption).font)
                    .foregroundStyle(snapColor)
                context.draw(label, at: CGPoint(x: (entry.segment.fromX + entry.segment.toX) / 2, y: (entry.segment.fromY + entry.segment.toY) / 2))
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

    /// "16" for a gap without token, "16 · space.s4" on a token, "15, nearest space.s4" beside one.
    private func labelText(_ label: DistanceLabel?, fallback: Double) -> Text {
        guard let label, let token = label.token else { return Text(verbatim: Self.number(label?.value ?? fallback)) }
        let number = Self.number(label.value)
        switch label.kind {
        case .plain: return Text(verbatim: number)
        case .onToken: return Text(verbatim: "\(number) · \(token)")
        case .nearToken: return Text("measure.nearest \(number) \(token)")
        }
    }

    private static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
