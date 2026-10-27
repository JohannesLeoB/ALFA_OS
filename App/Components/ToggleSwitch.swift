import Design
import SwiftUI

struct ToggleSwitch: View {
    @Environment(\.appearance) private var appearance
    @Binding var isOn: Bool
    let labelKey: String

    var body: some View {
        let height = Tokens.Spacing.step20
        let knob = Tokens.Spacing.step16
        Button(action: { isOn.toggle() }) {
            ZStack(alignment: .topLeading) {
                Capsule().fill(isOn ? appearance.color(\.ink) : Color.clear)
                Circle()
                    .fill(appearance.color(isOn ? \.lane : \.inkTertiary))
                    .frame(width: CGFloat(knob), height: CGFloat(knob))
                    .offset(
                        x: CGFloat(isOn ? Tokens.Size.toggleKnobOffsetOn : Tokens.Size.toggleKnobOffsetOff),
                        y: CGFloat(height - knob) / 2
                    )
            }
            .frame(width: CGFloat(Tokens.Spacing.step32), height: CGFloat(height))
            .ring(Pill(), isOn ? nil : appearance.color(\.lineStrong))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(appearance.text(labelKey))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .animation(appearance.ease(Tokens.Duration.toggle), value: isOn)
    }
}
