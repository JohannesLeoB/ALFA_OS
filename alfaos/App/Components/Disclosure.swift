import ShellCore
import SwiftUI

struct Disclosure<Content: View>: View {
    @Environment(\.design) private var design
    @Environment(\.accessibilityReduceMotion) private var reduced
    let open: Bool
    let help: String
    @ViewBuilder let content: Content
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: CGFloat(Design.Spacing.step8)) {
                content
                Glyph.small(.chevron)
                    .foregroundStyle(design.color(\.inkTertiary))
                    .rotationEffect(.degrees(open ? 180 : 0))
            }
            .padding(.horizontal, CGFloat(Design.Spacing.step8))
            .frame(height: CGFloat(Design.Spacing.step28))
            .background(Capsule().fill(hovering ? design.color(\.hover) : Color.clear))
            .contentShape(Capsule())
        }
        .buttonStyle(PressScale(scale: SheetValues.pressScaleDisclosure))
        .padding(.leading, -CGFloat(Design.Spacing.step8))
        .help(Text(verbatim: help))
        .onHover { hovering = $0 }
        .animation(ComponentMotion(reduced: reduced).curve(Design.Duration.chevron), value: open)
    }
}
