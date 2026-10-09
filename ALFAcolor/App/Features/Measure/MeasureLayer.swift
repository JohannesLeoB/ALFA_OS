import SwiftUI
import AppTheme
import BoardModel
import ALFAcolorCore

/// The line of the measuring tool, with its length and angle. In the coral color, one point wide at every zoom.
/// The layer takes no input.
struct MeasureLayer: View {
    var controller: CanvasController
    var interaction: CanvasInteraction

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if let line = interaction.measureLine,
           let segment = line.segment(viewport: controller.viewport),
           let reading = MeasureReading.of(line) {
            let color = theme.color(.coral, scheme)
            Canvas { context, _ in
                var path = Path()
                path.move(to: CGPoint(x: segment.fromX, y: segment.fromY))
                path.addLine(to: CGPoint(x: segment.toX, y: segment.toY))
                context.stroke(path, with: .color(color), lineWidth: SelectionStyle.lineWidth)
                let label = Self.label(reading)
                    .font(theme.text(.caption).font)
                    .foregroundStyle(color)
                let middle = CGPoint(x: (segment.fromX + segment.toX) / 2, y: (segment.fromY + segment.toY) / 2)
                context.draw(label, at: middle)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// The length in points and the angle, for example "120 pt · 30°".
    private static func label(_ reading: MeasureReading) -> Text {
        let length = LengthUnit.point.text(points: reading.length)
        let angle = reading.angle.formatted(.number.precision(.fractionLength(0...1)))
        return Text(verbatim: "\(length) ") + Text(LocalizedStringKey(LengthUnit.point.symbolKey)) + Text(verbatim: " · \(angle)°")
    }
}
