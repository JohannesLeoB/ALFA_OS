import Design
import Hub
import SwiftUI

struct SectionRow: View {
    @Environment(\.appearance) private var appearance
    let section: SettingsSection
    let value: String?
    let selected: Bool
    let separated: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row))
        let ink = InkSet.of(selected)
        Button(action: action) {
            MessageRow(fill: selected ? appearance.color(\.ink) : (hovering ? appearance.color(\.lane) : Color.clear),
                       ring: hovering && !selected ? appearance.color(\.lineStrong) : nil, separated: separated) {
                Mark(inverted: selected) { Text(verbatim: String(appearance.string(section.key).prefix(1))) }
            } content: {
                HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
                    appearance.text(section.key)
                        .lineLimit(1)
                        .font(.face(Tokens.TextSize.body, weight: Tokens.Weight.medium))
                        .foregroundStyle(appearance.color(selected ? \.lane : \.ink))
                    Spacer(minLength: 0)
                    if let value {
                        Text(verbatim: value)
                            .font(.face(Tokens.TextSize.small))
                            .monospacedDigit()
                            .foregroundStyle(appearance.color(ink.tertiary))
                    }
                }
                .frame(height: CGFloat(Tokens.LineHeight.notice))
                appearance.text(section.detailKey)
                    .lineLimit(1)
                    .font(.face(Tokens.TextSize.body))
                    .foregroundStyle(appearance.color(ink.tertiary))
                    .frame(height: CGFloat(Tokens.LineHeight.notice), alignment: .leading)
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
