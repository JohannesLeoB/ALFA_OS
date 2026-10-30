import Design
import Shell
import SwiftUI

struct LaneRow: View {
    @Environment(\.appearance) private var appearance
    let glyph: Icon
    let label: Text
    let selected: Bool
    var count: String?
    var countTone: KeyPath<Colors, ColorValue> = \.inkTertiary
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row))
        Button(action: action) {
            HStack(spacing: CGFloat(Tokens.Spacing.step20)) {
                Mark(inverted: selected, tone: selected ? \.onInverse : \.inkTertiary) { Glyph(glyph) }
                label
                    .designText(selected ? \.onInverse : \.ink, size: Tokens.TextSize.body, weight: selected ? .medium : .regular)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let count {
                    Counter(value: count, tone: countTone)
                }
            }
            .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
            .frame(height: CGFloat(Tokens.Size.rowHeight))
            .background(shape.fill(selected ? appearance.color(\.inverse) : Color.clear))
            .ring(shape, hovering && !selected ? appearance.color(\.lineStrong) : nil)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
