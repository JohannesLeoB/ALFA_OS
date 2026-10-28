import Design
import SwiftUI

struct SegmentOption<ID: Hashable>: Identifiable {
    let id: ID
    let label: Text
}

struct SegmentedControl<ID: Hashable>: View {
    @Environment(\.appearance) private var appearance
    let options: [SegmentOption<ID>]
    @Binding var selection: ID

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                let on = option.id == selection
                Button(action: { selection = option.id }) {
                    option.label
                        .lineLimit(1)
                        .typeStyle(Tokens.TextStyle.control)
                        .foregroundStyle(appearance.color(on ? \.onInverse : \.inkSecondary))
                        .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
                        .frame(height: CGFloat(Tokens.Spacing.step24))
                        .background(Capsule().fill(on ? appearance.color(\.inverse) : Color.clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(CGFloat(Tokens.Spacing.step2))
        .ring(Pill(), appearance.color(\.lineStrong))
    }
}
