import ShellCore
import SwiftUI

enum TextButtonKind {
    case accent
    case neutral
    case signal
    case plain
    case destructive
    case quiet
    case sheet
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
    var pressed = true
    let action: () -> Void
    @ViewBuilder let glyph: Glyph
    @State private var hovering = false

    private var fill: Color {
        switch kind {
        case .accent: return design.color(\.inverse)
        case .destructive: return design.color(\.lane)
        case .sheet: return design.color(\.sheet)
        case .neutral, .signal, .plain, .quiet: return hovering && !disabled ? design.color(\.hover) : Color.clear
        }
    }

    private var foreground: Color {
        switch kind {
        case .accent: design.color(\.onInverse)
        case .neutral: design.color(\.ink)
        case .signal, .destructive: design.color(\.signal)
        case .plain, .quiet: design.color(\.inkSecondary)
        case .sheet: design.color(\.sheetInk)
        }
    }

    private var ringColor: Color? {
        switch kind {
        case .accent, .plain: nil
        case .neutral, .quiet: design.color(\.lineStrong)
        case .signal, .destructive: design.color(\.signal)
        case .sheet: design.color(\.sheetLineStrong)
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
            .font(kind == .sheet ? Font(Typeface.sheet(size: Design.TextSize.small, weight: .medium))
                  : .face(Design.TextSize.small, weight: Design.Weight.medium))
            .foregroundStyle(foreground)
            .padding(.leading, CGFloat(Glyph.self == EmptyView.self ? Design.Spacing.step12 : Design.Spacing.step8))
            .padding(.trailing, CGFloat(Design.Spacing.step12))
            .frame(height: height)
            .background(Capsule().fill(fill))
            .ring(Capsule(), ringColor)
            .contentShape(Capsule())
            .opacity(disabled ? SheetValues.disabledOpacity : 1)
        }
        .buttonStyle(PressScale(scale: disabled || !pressed ? 1 : SheetValues.pressScale))
        .allowsHitTesting(!disabled)
        .onHover { hovering = $0 }
        .animation(ComponentMotion(reduced: reduced).curve(Design.Duration.hover), value: hovering)
    }
}

extension TextButton where Glyph == EmptyView {
    init(label: Text, kind: TextButtonKind = .neutral, size: TextButtonSize = .regular, disabled: Bool = false, pressed: Bool = true,
         action: @escaping () -> Void) {
        self.init(label: label, kind: kind, size: size, disabled: disabled, pressed: pressed, action: action) { EmptyView() }
    }
}

struct TextMenuButton: View {
    let label: Text
    var kind = TextButtonKind.neutral
    var disabled = false
    var width = Design.Size.menuWidthRow
    let entries: () -> [MenuEntry]
    @State private var anchor = AnchorBox()

    var body: some View {
        TextButton(label: label, kind: kind, disabled: disabled, action: open)
            .background(AnchorProbe(box: anchor))
    }

    private func open() {
        guard let rect = anchor.screenRect() else { return }
        MenuPanel.shared.show(entries: entries(), width: width, anchor: .rect(rect), window: NSApp.keyWindow)
    }
}
