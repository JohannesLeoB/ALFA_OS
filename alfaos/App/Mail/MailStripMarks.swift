import Mail
import ShellCore
import SwiftUI

struct MailStripMarks: View {
    let model: MailModel
    let lane: Lane
    let height: Double

    var body: some View {
        VStack(spacing: CGFloat(Design.Spacing.step8)) {
            ForEach(model.stripMarks(lane, height: height)) { mark in
                StripMarkView(mark: mark) { Task { await model.run(mark.run) } }
            }
        }
        .padding(.vertical, CGFloat(Design.Spacing.step8))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct StripMarkView: View {
    @Environment(\.design) private var design
    @Environment(\.hairline) private var hairline
    let mark: MailStripMark
    let action: () -> Void

    var body: some View {
        let side = CGFloat(Design.Size.symbolSize)
        Button(action: action) {
            Group {
                switch mark.face {
                case .glyph(let glyph): Glyph(glyph)
                case .text(let text): Text(verbatim: text).lineLimit(1)
                }
            }
            .designText(mark.selected ? \.lane : \.inkSecondary, size: Design.TextSize.small, weight: .medium)
            .frame(width: side, height: side)
            .background(Circle().fill(mark.selected ? design.color(\.ink) : Color.clear))
            .overlay(Circle().strokeBorder(mark.selected ? Color.clear : design.color(\.lineStrong), lineWidth: hairline))
            .overlay(alignment: .topTrailing) {
                if mark.dot {
                    Circle().fill(design.color(\.ink))
                        .frame(width: CGFloat(Design.Spacing.statusDot), height: CGFloat(Design.Spacing.statusDot))
                        .overlay(Circle().strokeBorder(design.color(\.lane), lineWidth: CGFloat(Design.Size.markSeparatorRing)))
                        .offset(x: hairline, y: -hairline)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(mark.help.key.map { word($0) } ?? Text(verbatim: mark.help.text))
        .accessibilityLabel(mark.help.key.map { word($0) } ?? Text(verbatim: mark.help.text))
    }
}
