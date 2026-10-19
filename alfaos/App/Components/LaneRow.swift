import ShellCore
import SwiftUI

struct LaneRow: View {
    @Environment(\.design) private var design
    let glyph: Icon
    let label: Text
    let selected: Bool
    var count: String?
    var countTone: KeyPath<DesignColors, RGB> = \.inkTertiary
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row))
        Button(action: action) {
            HStack(spacing: CGFloat(SheetValues.rowSpacing)) {
                Mark(inverted: selected, tone: selected ? \.lane : \.inkTertiary) { Glyph(glyph) }
                label
                    .designText(selected ? \.lane : \.ink, size: Design.TextSize.body, weight: selected ? .medium : .regular)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let count {
                    Counter(value: count, tone: countTone)
                }
            }
            .padding(.horizontal, CGFloat(Design.Spacing.step8))
            .frame(height: CGFloat(Design.Size.rowHeight))
            .background(shape.fill(selected ? design.color(\.ink) : Color.clear))
            .ring(shape, hovering && !selected ? design.color(\.lineStrong) : nil)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
