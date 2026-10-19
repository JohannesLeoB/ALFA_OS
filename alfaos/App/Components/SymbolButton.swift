import ShellCore
import SwiftUI

enum SymbolHover {
    case ring
    case fill
    case none
}

struct SymbolButton: View {
    @Environment(\.design) private var design
    @Environment(\.accessibilityReduceMotion) private var reduced
    let help: String
    let glyph: Icon
    var selected = false
    var disabled = false
    var tone: KeyPath<DesignColors, RGB> = \.inkTertiary
    var hoverTone: KeyPath<DesignColors, RGB> = \.ink
    var ringed = true
    var hover = SymbolHover.ring
    let action: () -> Void
    @State private var hovering = false

    private var live: Bool { hovering && !disabled }

    private var foreground: Color {
        if selected { return design.color(\.onInverse) }
        return design.color(live && hover != .none ? hoverTone : tone)
    }

    private var fill: Color {
        if selected { return design.color(\.inverse) }
        return live && hover == .fill ? design.color(\.hover) : Color.clear
    }

    private var ring: Color? {
        if selected { return nil }
        if live && hover == .ring { return design.color(\.inkTertiary) }
        return ringed ? design.color(\.lineStrong) : nil
    }

    var body: some View {
        let side = CGFloat(Design.Size.symbolSize)
        Button(action: { if !disabled { action() } }) {
            Glyph(glyph)
                .frame(width: side, height: side)
                .foregroundStyle(foreground)
                .background(Capsule().fill(fill))
                .ring(Capsule(), ring)
                .contentShape(Capsule())
                .opacity(disabled ? SheetValues.disabledOpacity : 1)
        }
        .buttonStyle(.plain)
        .help(Text(verbatim: help))
        .accessibilityLabel(Text(verbatim: help))
        .allowsHitTesting(!disabled)
        .onHover { hovering = $0 }
        .animation(ComponentMotion(reduced: reduced).curve(Design.Duration.hover), value: live)
    }
}
