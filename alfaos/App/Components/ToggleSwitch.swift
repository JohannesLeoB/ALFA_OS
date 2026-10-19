import ShellCore
import SwiftUI

struct ToggleSwitch: View {
    @Environment(\.design) private var design
    @Environment(\.accessibilityReduceMotion) private var reduced
    @Binding var isOn: Bool
    let labelKey: String

    var body: some View {
        let height = Design.Spacing.step20
        let knob = Design.Spacing.step16
        Button(action: { isOn.toggle() }) {
            ZStack(alignment: .topLeading) {
                Capsule().fill(isOn ? design.color(\.ink) : Color.clear)
                Circle()
                    .fill(design.color(isOn ? \.lane : \.inkTertiary))
                    .frame(width: CGFloat(knob), height: CGFloat(knob))
                    .offset(
                        x: CGFloat(isOn ? Design.Size.toggleKnobOffsetOn : Design.Size.toggleKnobOffsetOff),
                        y: CGFloat(height - knob) / 2
                    )
            }
            .frame(width: CGFloat(Design.Spacing.step32), height: CGFloat(height))
            .ring(Pill(), isOn ? nil : design.color(\.lineStrong))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(word(labelKey))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .animation(ComponentMotion(reduced: reduced).curve(Design.Duration.toggle), value: isOn)
    }
}
