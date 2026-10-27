import Design
import Shell
import SwiftUI

struct CardHeadButton: View {
    @Environment(\.appearance) private var appearance
    let help: String
    let glyph: Icon
    let ink: Color
    var dim = true
    var fills = true
    var pressed = true
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let side = CGFloat(Tokens.Size.symbolSize)
        Button(action: action) {
            Glyph(glyph)
                .frame(width: side, height: side)
                .foregroundStyle(ink)
                .opacity(hovering || !dim ? 1 : SheetValues.closeOpacity)
                .background(Circle().fill(hovering && fills ? appearance.color(\.hover) : Color.clear))
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle(scale: pressed ? SheetValues.pressScale : 1))
        .help(Text(verbatim: help))
        .accessibilityLabel(Text(verbatim: help))
        .onHover { hovering = $0 }
    }
}
