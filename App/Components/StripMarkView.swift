import Design
import Shell
import SwiftUI

struct StripMarkItem: Identifiable {
    let id: String
    let face: StripFace
    let help: Text
    let selected: Bool
    let dot: Bool
    var accent = false
    let action: () -> Void
}

struct StripMarks: View {
    let items: [StripMarkItem]

    var body: some View {
        VStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            ForEach(items.filter { !$0.accent }) { item in
                StripMarkView(item: item)
            }
            Spacer(minLength: 0)
            ForEach(items.filter(\.accent)) { item in
                StripMarkView(item: item)
            }
        }
        .padding(.vertical, CGFloat(Tokens.Spacing.step8))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct StripMarkView: View {
    @Environment(\.appearance) private var appearance
    let item: StripMarkItem

    var body: some View {
        let side = CGFloat(Tokens.Size.symbolSize)
        let line = CGFloat(Tokens.Size.hairline)
        Button(action: item.action) {
            Group {
                switch item.face {
                case .glyph(let icon): Glyph(icon)
                case .text(let value): Text(verbatim: value).lineLimit(1)
                }
            }
            .designText(item.accent || item.selected ? \.lane : \.inkSecondary, size: Tokens.TextSize.small, weight: .medium)
            .frame(width: side, height: side)
            .background(Circle().fill(item.accent || item.selected ? appearance.color(\.ink) : Color.clear))
            .overlay(Circle().strokeBorder(item.accent || item.selected ? Color.clear : appearance.color(\.lineStrong), lineWidth: line))
            .overlay(alignment: .topTrailing) {
                if item.dot {
                    Circle().fill(appearance.color(\.ink))
                        .frame(width: CGFloat(Tokens.Spacing.statusDot), height: CGFloat(Tokens.Spacing.statusDot))
                        .background(Circle().fill(appearance.color(\.lane)).padding(-CGFloat(Tokens.Size.markSeparatorRing)))
                        .offset(x: line, y: -line)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(item.help)
        .accessibilityLabel(item.help)
    }
}
