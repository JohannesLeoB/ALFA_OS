import Design
import Shell
import SwiftUI

enum SymbolHover {
    case ring
    case fill
    case tint
    case none
}

struct SymbolButton: View {
    @Environment(\.appearance) private var appearance
    let help: String
    let glyph: Icon
    var selected = false
    var disabled = false
    var dimmed: Bool?
    var side = Tokens.Size.symbolSize
    var glyphSize = SheetValues.iconSize
    var tone: KeyPath<Colors, ColorValue>? = \.inkTertiary
    var hoverTone: KeyPath<Colors, ColorValue>? = \.ink
    var ringed = true
    var plate: KeyPath<Colors, ColorValue>?
    var ringTone: KeyPath<Colors, ColorValue> = \.lineStrong
    var hover = SymbolHover.ring
    var hoverFill: KeyPath<Colors, ColorValue> = \.hover
    var pressed = true
    let action: () -> Void
    @State private var hovering = false

    private var live: Bool { hovering && !disabled }

    private var foreground: AnyShapeStyle {
        if selected { return AnyShapeStyle(appearance.color(\.onInverse)) }
        let key = live && hover != .none ? hoverTone ?? tone : tone
        return key.map { AnyShapeStyle(appearance.color($0)) } ?? AnyShapeStyle(.foreground)
    }

    private var fill: Color {
        if selected { return appearance.color(\.inverse) }
        if live && hover == .fill { return appearance.color(hoverFill) }
        return plate.map { appearance.color($0) } ?? Color.clear
    }

    private var ring: Color? {
        if selected { return nil }
        if live && hover == .ring { return appearance.color(\.inkTertiary) }
        return ringed ? appearance.color(ringTone) : nil
    }

    var body: some View {
        Button(action: action) {
            Glyph(glyph, size: glyphSize)
                .frame(width: CGFloat(side), height: CGFloat(side))
                .foregroundStyle(foreground)
                .background(Circle().fill(fill))
                .ring(Circle(), ring)
                .contentShape(Circle())
                .opacity(dimmed ?? disabled ? Tokens.Opacity.disabled : 1)
        }
        .buttonStyle(PressScaleButtonStyle(scale: disabled || !pressed ? 1 : SheetValues.pressScale))
        .disabled(disabled)
        .help(Text(verbatim: help))
        .accessibilityLabel(Text(verbatim: help))
        .onHover { hovering = $0 }
        .animation(appearance.ease(Tokens.Duration.hover), value: live)
        .animation(appearance.ease(Tokens.Duration.hover), value: plate)
    }
}
