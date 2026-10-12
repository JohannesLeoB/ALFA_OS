import SwiftUI
import AppTheme
import ALFAcolorCore
import BoardModel

/// One ruler along an edge of the canvas. The ticks come from `RulerScale`; this view only draws them.
/// The ruler takes clicks on its own strip, and its unit is chosen with a right click.
struct RulerView: View {
    /// The top ruler runs left to right; the left ruler runs top to bottom.
    enum Along: Sendable {
        case horizontal, vertical
    }

    var along: Along
    var scale: RulerScale
    /// The board point, on this ruler's axis, where the frame that the ruler measures from begins.
    var origin: Double
    var viewport: Viewport
    /// Canvas position of the first point of the ruler, along its axis.
    var lead: Double
    /// Canvas position of the ruler's edge across its axis: the top of a horizontal ruler, the left of a vertical one.
    var cross: Double
    /// Called with the unit that the right click picks.
    var onPickUnit: (LengthUnit) -> Void
    /// Called while a guide is pulled out of the ruler, with the pointer in canvas points, and again when it is let go.
    /// nil turns the pulling off.
    var onPull: ((CGPoint, Bool) -> Void)?

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    /// Pulling a guide: a drag that starts on the strip. Its position is the pointer in canvas points.
    private var pull: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .local)
            .onChanged { value in
                onPull?(canvasPoint(value.location), false)
            }
            .onEnded { value in
                onPull?(canvasPoint(value.location), true)
            }
    }

    private func canvasPoint(_ location: CGPoint) -> CGPoint {
        along == .horizontal
            ? CGPoint(x: lead + location.x, y: cross + location.y)
            : CGPoint(x: cross + location.x, y: lead + location.y)
    }

    var body: some View {
        let edge = theme.color(.border, scheme)
        let ink = theme.color(.textMuted, scheme)
        let font = theme.text(.caption).font
        Canvas { context, size in
            let length = along == .horizontal ? size.width : size.height
            let offset = along == .horizontal ? viewport.offsetX : viewport.offsetY
            let zoom = viewport.zoom
            // Board distances from the origin at the two ends of the ruler.
            let start = offset + lead / zoom - origin
            let end = offset + (lead + length) / zoom - origin
            let thickness = along == .horizontal ? size.height : size.width
            let major = theme.space(.s5)
            let minor = theme.space(.s2)
            for tick in scale.ticks(from: start, to: end) {
                // Canvas position of the tick, then the position on this ruler.
                let local = (tick.points + origin - offset) * zoom - lead
                let mark = tick.isMajor ? major : minor
                var path = Path()
                if along == .horizontal {
                    path.move(to: CGPoint(x: local, y: thickness))
                    path.addLine(to: CGPoint(x: local, y: thickness - mark))
                } else {
                    path.move(to: CGPoint(x: thickness, y: local))
                    path.addLine(to: CGPoint(x: thickness - mark, y: local))
                }
                context.stroke(path, with: .color(ink), lineWidth: SelectionStyle.lineWidth)
                if tick.isMajor {
                    let label = Text(verbatim: scale.unit.text(points: tick.points, scale: scale.scale))
                        .font(font)
                        .foregroundStyle(ink)
                    let at = along == .horizontal
                        ? CGPoint(x: local + major, y: thickness / 2)
                        : CGPoint(x: thickness / 2, y: local + major)
                    context.draw(label, at: at, anchor: along == .horizontal ? .leading : .top)
                }
            }
            var border = Path()
            if along == .horizontal {
                border.move(to: CGPoint(x: 0, y: thickness))
                border.addLine(to: CGPoint(x: size.width, y: thickness))
            } else {
                border.move(to: CGPoint(x: thickness, y: 0))
                border.addLine(to: CGPoint(x: thickness, y: size.height))
            }
            context.stroke(border, with: .color(edge), lineWidth: SelectionStyle.lineWidth)
        }
        .background(theme.color(.surface, scheme))
        .gesture(pull)
        .contextMenu {
            ForEach(LengthUnit.allCases, id: \.self) { unit in
                Button {
                    onPickUnit(unit)
                } label: {
                    Text(LocalizedStringKey(unit.symbolKey))
                }
            }
        }
        .accessibilityLabel(along == .horizontal ? "ruler.horizontal" : "ruler.vertical")
    }
}
