import ShellCore
import SwiftUI

struct AddressButton<Label: View>: View {
    @Environment(\.design) private var design
    var capsule = false
    let action: () -> Void
    @ViewBuilder let label: Label
    @State private var hovering = false

    var body: some View {
        if capsule {
            Button(action: action) {
                label
                    .padding(.horizontal, CGFloat(Design.Spacing.step8))
                    .frame(height: CGFloat(Design.Spacing.step28))
                    .background(Capsule().fill(hovering ? design.color(\.hover) : Color.clear))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.leading, -CGFloat(Design.Spacing.step8))
            .onHover { hovering = $0 }
        } else {
            Button(action: action) { label }
                .buttonStyle(.plain)
        }
    }
}
