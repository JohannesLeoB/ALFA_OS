import Design
import SwiftUI

struct EnvelopeButton: View {
    @Environment(\.appearance) private var appearance
    let open: Bool
    let alert: Bool
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let side = CGFloat(Tokens.Size.symbolSize)
        Button(action: action) {
            EnvelopeStack(open: open)
                .frame(width: side, height: side)
                .foregroundStyle(appearance.color(hovering ? \.ink : \.inkTertiary))
                .ring(Capsule(), appearance.color(hovering ? \.inkTertiary : \.lineStrong))
                .overlay(alignment: .topTrailing) { if alert { AccountAlert() } }
                .contentShape(Capsule())
        }
        .buttonStyle(PressScaleButtonStyle(scale: SheetValues.pressScale))
        .help(Text(verbatim: help))
        .accessibilityLabel(Text(verbatim: help))
        .accessibilityAddTraits(open ? .isSelected : [])
        .onHover { hovering = $0 }
        .animation(appearance.ease(Tokens.Duration.hover), value: hovering)
    }
}
