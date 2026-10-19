import ShellCore
import SwiftUI

enum TextButtonKind {
    case accent
    case neutral
    case signal
    case plain
    case destructive
}

enum TextButtonSize {
    case regular
    case compact
}

struct TextButton<Glyph: View>: View {
    @Environment(\.design) private var design
    @Environment(\.accessibilityReduceMotion) private var reduced
    let label: Text
    var kind = TextButtonKind.neutral
    var size = TextButtonSize.regular
    var disabled = false
    let action: () -> Void
    @ViewBuilder let glyph: Glyph
    @State private var hovering = false

    private var fill: Color {
        switch kind {
        case .accent: return design.color(\.inverse)
        case .destructive: return design.color(\.lane)
        case .neutral, .signal, .plain: return hovering && !disabled ? design.color(\.hover) : Color.clear
        }
    }

    private var foreground: Color {
        switch kind {
        case .accent: design.color(\.onInverse)
        case .neutral: design.color(\.ink)
        case .signal, .destructive: design.color(\.signal)
        case .plain: design.color(\.inkSecondary)
        }
    }

    private var ringColor: Color? {
        switch kind {
        case .accent, .plain: nil
        case .neutral: design.color(\.lineStrong)
        case .signal, .destructive: design.color(\.signal)
        }
    }

    private var height: CGFloat {
        CGFloat(size == .regular ? Design.Spacing.step28 : Design.Size.chipHeight)
    }

    var body: some View {
        Button(action: { if !disabled { action() } }) {
            HStack(spacing: CGFloat(Design.Spacing.step8)) {
                glyph
                label.lineLimit(1)
            }
            .font(.face(Design.TextSize.small, weight: Design.Weight.medium))
            .foregroundStyle(foreground)
            .padding(.leading, CGFloat(Glyph.self == EmptyView.self ? Design.Spacing.step12 : Design.Spacing.step8))
            .padding(.trailing, CGFloat(Design.Spacing.step12))
            .frame(height: height)
            .background(Capsule().fill(fill))
            .ring(Capsule(), ringColor)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!disabled)
        .onHover { hovering = $0 }
        .animation(ComponentMotion(reduced: reduced).curve(Design.Duration.hover), value: hovering)
    }
}

extension TextButton where Glyph == EmptyView {
    init(label: Text, kind: TextButtonKind = .neutral, size: TextButtonSize = .regular, disabled: Bool = false, action: @escaping () -> Void) {
        self.init(label: label, kind: kind, size: size, disabled: disabled, action: action) { EmptyView() }
    }
}
