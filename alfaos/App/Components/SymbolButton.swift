import ShellCore
import SwiftUI

struct SymbolButton<Glyph: View>: View {
    @Environment(\.design) private var design
    @Environment(\.accessibilityReduceMotion) private var reduced
    let titleKey: String
    var selected = false
    var ringed = true
    var tone: KeyPath<DesignColors, RGB> = \.inkTertiary
    let action: () -> Void
    @ViewBuilder let glyph: Glyph
    @State private var hovering = false

    private var foreground: Color {
        if selected { return design.color(\.onInverse) }
        return design.color(hovering ? \.ink : tone)
    }

    private var ringColor: Color? {
        if selected { return nil }
        if hovering { return design.color(\.inkTertiary) }
        return ringed ? design.color(\.lineStrong) : nil
    }

    var body: some View {
        let size = CGFloat(Design.Size.symbolSize)
        Button(action: action) {
            glyph
                .frame(width: size, height: size)
                .foregroundStyle(foreground)
                .background(Capsule().fill(selected ? design.color(\.inverse) : Color.clear))
                .ring(Capsule(), ringColor)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(word(titleKey))
        .accessibilityLabel(word(titleKey))
        .onHover { hovering = $0 }
        .animation(ComponentMotion(reduced: reduced).curve(Design.Duration.hover), value: hovering)
    }
}
