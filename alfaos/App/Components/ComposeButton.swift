import ShellCore
import SwiftUI

struct ComposeButton: View {
    @Environment(\.design) private var design
    @Environment(\.hairline) private var hairline
    @Environment(\.accessibilityReduceMotion) private var reduced
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: CGFloat(SheetValues.rowSpacing)) {
                Glyph(.compose)
                    .frame(width: CGFloat(Design.Size.symbolSize), height: CGFloat(Design.Size.symbolSize))
                    .overlay(Circle().strokeBorder(design.color(\.onInverse).opacity(Design.Opacity.ringOnColor), lineWidth: hairline))
                word("mail.action.compose")
                    .designText(\.onInverse, size: Design.TextSize.body)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, CGFloat(Design.Spacing.step8))
            .padding(.trailing, CGFloat(Design.Spacing.step12))
            .frame(height: CGFloat(Design.Size.rowHeight))
            .background(RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row)).fill(design.color(\.inverse)))
            .opacity(hovering ? SheetValues.hoverRowOpacity : 1)
            .contentShape(RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row)))
        }
        .buttonStyle(PressScale(scale: SheetValues.pressScaleCompose))
        .keyboardShortcut("n", modifiers: .command)
        .help(word("mail.action.compose"))
        .padding(CGFloat(Design.Spacing.step8))
        .onHover { hovering = $0 }
        .animation(ComponentMotion(reduced: reduced).curve(Design.Duration.hover), value: hovering)
    }
}
