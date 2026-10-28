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
    var tone: KeyPath<Colors, ColorValue> = \.inkTertiary
    var hoverTone: KeyPath<Colors, ColorValue> = \.ink
    var ringed = true
    var plate: KeyPath<Colors, ColorValue>?
    var ringTone: KeyPath<Colors, ColorValue> = \.lineStrong
    var hover = SymbolHover.ring
    var pressed = true
    let action: () -> Void
    @State private var hovering = false

    private var live: Bool { hovering && !disabled }

    private var foreground: Color {
        if selected { return appearance.color(\.onInverse) }
        return appearance.color(live && hover != .none ? hoverTone : tone)
    }

    private var fill: Color {
        if selected { return appearance.color(\.inverse) }
        if live && hover == .fill { return appearance.color(\.hover) }
        return plate.map { appearance.color($0) } ?? Color.clear
    }

    private var ring: Color? {
        if selected { return nil }
        if live && hover == .ring { return appearance.color(\.inkTertiary) }
        return ringed ? appearance.color(ringTone) : nil
    }

    var body: some View {
        let side = CGFloat(Tokens.Size.symbolSize)
        Button(action: { if !disabled { action() } }) {
            Glyph(glyph)
                .frame(width: side, height: side)
                .foregroundStyle(foreground)
                .background(Circle().fill(fill))
                .ring(Circle(), ring)
                .contentShape(Circle())
                .opacity(disabled ? Tokens.Opacity.disabled : 1)
        }
        .buttonStyle(PressScaleButtonStyle(scale: disabled || !pressed ? 1 : SheetValues.pressScale))
        .help(Text(verbatim: help))
        .accessibilityLabel(Text(verbatim: help))
        .allowsHitTesting(!disabled)
        .onHover { hovering = $0 }
        .animation(appearance.ease(Tokens.Duration.hover), value: live)
    }
}
