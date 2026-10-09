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
        }
        .modifier(Lift(detail: detail))
        .overlay(alignment: .topLeading) {
            if detail == .full {
                label.alignmentGuide(.top) { dimensions in dimensions[.bottom] + theme.space(.s2) }
            }
        }
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
