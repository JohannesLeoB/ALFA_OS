import ShellCore
import SwiftUI

struct SegmentOption<ID: Hashable>: Identifiable {
    let id: ID
    let label: Text
}

struct SegmentedControl<ID: Hashable>: View {
    @Environment(\.design) private var design
    let options: [SegmentOption<ID>]
    @Binding var selection: ID

    var body: some View {
        let inset = CGFloat(Design.Spacing.step28 - Design.Size.chipHeight) / 2
        HStack(spacing: 0) {
            ForEach(options) { option in
                let on = option.id == selection
                Button(action: { selection = option.id }) {
                    option.label
                        .lineLimit(1)
                        .font(.system(size: CGFloat(Design.TextSize.small), weight: .design(Design.Weight.medium)))
                        .foregroundStyle(design.color(on ? \.onInverse : \.inkSecondary))
                        .padding(.horizontal, CGFloat(Design.Spacing.step8))
                        .frame(height: CGFloat(Design.Size.chipHeight))
                        .background(Capsule().fill(on ? design.color(\.inverse) : Color.clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(inset)
        .ring(Capsule(), design.color(\.lineStrong))
    }
}
