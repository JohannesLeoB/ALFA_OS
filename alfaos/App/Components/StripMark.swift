import ShellCore
import SwiftUI

struct StripMarkItem: Identifiable {
    let id: String
    let face: StripFace
    let help: Text
    let selected: Bool
    let dot: Bool
    let action: () -> Void
}

struct StripMarks: View {
    let items: [StripMarkItem]

    var body: some View {
        VStack(spacing: CGFloat(Design.Spacing.step8)) {
            ForEach(items) { item in
                StripMark(item: item)
            }
        }
        .padding(.vertical, CGFloat(Design.Spacing.step8))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct StripMark: View {
    @Environment(\.design) private var design
    @Environment(\.hairline) private var hairline
    let item: StripMarkItem

    var body: some View {
        let side = CGFloat(Design.Size.symbolSize)
        Button(action: item.action) {
            Group {
                switch item.face {
                case .glyph(let icon): Glyph(icon)
                case .text(let value): Text(verbatim: value).lineLimit(1)
                }
            }
            .designText(item.selected ? \.lane : \.inkSecondary, size: Design.TextSize.small, weight: .medium)
            .frame(width: side, height: side)
            .background(Circle().fill(item.selected ? design.color(\.ink) : Color.clear))
            .overlay(Circle().strokeBorder(item.selected ? Color.clear : design.color(\.lineStrong), lineWidth: hairline))
            .overlay(alignment: .topTrailing) {
                if item.dot {
                    Circle().fill(design.color(\.ink))
                        .frame(width: CGFloat(Design.Spacing.statusDot), height: CGFloat(Design.Spacing.statusDot))
                        .background(Circle().fill(design.color(\.lane)).padding(-CGFloat(Design.Size.markSeparatorRing)))
                        .offset(x: hairline, y: -hairline)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(item.help)
        .accessibilityLabel(item.help)
    }
}
