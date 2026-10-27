import Design
import SwiftUI

struct AddressButton<Label: View>: View {
    @Environment(\.appearance) private var appearance
    var capsule = false
    let action: () -> Void
    @ViewBuilder let label: Label
    @State private var hovering = false

    var body: some View {
        if capsule {
            Button(action: action) {
                label
                    .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
                    .frame(height: CGFloat(Tokens.Spacing.step28))
                    .background(Capsule().fill(hovering ? appearance.color(\.hover) : Color.clear))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.leading, -CGFloat(Tokens.Spacing.step8))
            .onHover { hovering = $0 }
        } else {
            Button(action: action) { label }
                .buttonStyle(.plain)
        }
    }
}
