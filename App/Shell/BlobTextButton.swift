import Design
import SwiftUI

struct BlobTextButton: View {
    @Environment(\.appearance) private var appearance
    let label: Text
    var plate: KeyPath<Colors, ColorValue> = \.inverseField
    var hoverPlate: KeyPath<Colors, ColorValue>?
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            label
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, CGFloat(Tokens.Spacing.step12))
                .frame(height: CGFloat(Tokens.Spacing.step28))
                .background(Capsule().fill(appearance.color(hovering ? hoverPlate ?? plate : plate)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(appearance.ease(Tokens.Duration.hover), value: hovering)
    }
}
