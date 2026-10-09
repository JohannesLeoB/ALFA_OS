import SwiftUI
import AppTheme
import BoardModel

/// The frame of a device: a sheet at the size of the device, with its name and sizes above it.
/// The sheet has the border of a card and the shadow of the first level. The label stands above the sheet,
/// outside the frame, and is left out at small zoom.
struct FrameView: View {
    let frame: FrameDisplay
    let detail: DetailLevel
    let zoom: Double

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let hairline = Hairline.width(zoom: zoom, scale: displayScale)
        ZStack(alignment: .topLeading) {
            Rectangle().fill(theme.color(.surface, scheme))
            Rectangle().strokeBorder(theme.color(.border, scheme), lineWidth: hairline)
            if detail == .full, let lines = frame.gridLines {
                gridCanvas(lines, hairline: hairline)
            }
        }
        .modifier(Lift(detail: detail))
        .overlay(alignment: .topLeading) {
            if detail == .full {
                label.alignmentGuide(.top) { dimensions in dimensions[.bottom] + theme.space(.s2) }
            }
        }
    }

    /// Opacity of the column fill and of the baselines. The colors come from the theme.
    private static let columnOpacity = 0.10
    private static let baselineOpacity = 0.12

    /// The grid on the sheet: columns as a light fill, baselines as hairlines, margins dashed. The canvas takes
    /// no input, so clicks reach the items and the sheet below it.
    private func gridCanvas(_ lines: FrameGridLines, hairline: CGFloat) -> some View {
        let columnColor = theme.color(.coral, scheme).opacity(Self.columnOpacity)
        let baselineColor = theme.color(.accent, scheme).opacity(Self.baselineOpacity)
        let marginColor = theme.color(.border, scheme)
        let dash = [theme.space(.s1), theme.space(.s1)]
        let inner = lines.inner
        return Canvas { context, size in
            for column in lines.columns {
                context.fill(Path(CGRect(x: column.x, y: column.y, width: column.w, height: column.h)), with: .color(columnColor))
            }
            var rules = Path()
            for y in lines.baselines {
                rules.move(to: CGPoint(x: 0, y: y))
                rules.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(rules, with: .color(baselineColor), lineWidth: hairline)
            let margins = Path(CGRect(x: inner.x, y: inner.y, width: inner.w, height: inner.h))
            context.stroke(margins, with: .color(marginColor), style: StrokeStyle(lineWidth: hairline, dash: dash))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The name, the size in points, the size in pixels at the scale, and a note for a template size.
    private var label: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LocalizedStringKey(frame.nameKey ?? "item.kind.frame"))
            Text("frame.size.pt \(frame.widthPoints) \(frame.heightPoints)")
            Text("frame.size.px \(frame.widthPixels) \(frame.heightPixels) \(frame.scale)")
            if frame.isTemplate {
                Text("frame.template")
            }
        }
        .font(theme.text(.caption).font)
        .lineLimit(1)
        .fixedSize()
        .foregroundStyle(theme.color(.textMuted, scheme))
    }
}
