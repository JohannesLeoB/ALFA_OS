import Design
import Shell
import SwiftUI

struct BlobSymbolButton: View {
    @Environment(\.appearance) private var appearance
    let help: String
    let glyph: Icon
    var side = Tokens.Spacing.step28
    var size = SheetValues.iconSize
    var dimmed = false
    var plate: KeyPath<Colors, ColorValue>?
    var tone: KeyPath<Colors, ColorValue>?
    var hovers = true
    let action: () -> Void
    @State private var hovering = false

    private var fill: Color {
        if let plate { return appearance.color(plate) }
        return hovers && hovering ? appearance.color(\.inverseHot) : Color.clear
    }

    var body: some View {
        Button(action: action) {
            Glyph(glyph, size: size)
                .foregroundStyle(tone.map { AnyShapeStyle(appearance.color($0)) } ?? AnyShapeStyle(.foreground))
                .frame(width: CGFloat(side), height: CGFloat(side))
                .background(Circle().fill(fill))
                .contentShape(Circle())
                .opacity(dimmed ? Tokens.Opacity.disabled : 1)
        }
        .buttonStyle(.plain)
        .help(Text(verbatim: help))
        .accessibilityLabel(Text(verbatim: help))
        .onHover { hovering = $0 }
        .animation(appearance.ease(Tokens.Duration.hover), value: hovering)
        .animation(appearance.ease(Tokens.Duration.hover), value: plate)
    }
}
