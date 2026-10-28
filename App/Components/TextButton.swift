import AppKit
import Design
import Shell
import SwiftUI

enum TextButtonKind {
    case accent
    case neutral
    case signal
    case plain
    case quiet
    case sheet
}

enum TextButtonSize {
    case regular
    case compact
}

struct TextButton<Glyph: View>: View {
    @Environment(\.appearance) private var appearance
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
        case .accent: return appearance.color(\.inverse)
        case .sheet: return appearance.color(\.sheet)
        case .neutral, .signal, .plain, .quiet: return hovering && !disabled ? appearance.color(\.hover) : Color.clear
        }
    }

    private var foreground: Color {
        switch kind {
        case .accent: appearance.color(\.onInverse)
        case .neutral: appearance.color(\.ink)
        case .signal: appearance.color(\.signal)
        case .plain, .quiet: appearance.color(\.inkSecondary)
        case .sheet: appearance.color(\.sheetInk)
        }
    }

    private var ringColor: Color? {
        switch kind {
        case .accent, .plain: nil
        case .neutral, .quiet: appearance.color(\.lineStrong)
        case .signal: appearance.color(\.signal)
        case .sheet: appearance.color(\.sheetLineStrong)
        }
    }

    private var height: CGFloat {
        CGFloat(size == .regular ? Tokens.Spacing.step28 : Tokens.Size.chipHeight)
    }

    var body: some View {
        Button(action: { if !disabled { action() } }) {
            HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
                glyph
                label.lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)
            .font(kind == .sheet ? Font(Typeface.sheet(size: Tokens.TextStyle.control.size, weight: .medium)) : .face(Tokens.TextStyle.control))
            .tracking(CGFloat(Tokens.Tracking.control * Tokens.TextStyle.control.size))
            .foregroundStyle(foreground)
            .padding(.leading, CGFloat(Glyph.self == EmptyView.self ? Tokens.Spacing.step12 : Tokens.Spacing.step8))
            .padding(.trailing, CGFloat(Tokens.Spacing.step12))
            .frame(height: height)
            .background(Capsule().fill(fill))
            .ring(Pill(), ringColor)
            .contentShape(Capsule())
            .opacity(disabled ? SheetValues.disabledOpacity : 1)
        }
        .buttonStyle(PressScaleButtonStyle(scale: disabled || !pressed ? 1 : SheetValues.pressScale))
        .allowsHitTesting(!disabled)
        .onHover { hovering = $0 }
        .animation(appearance.ease(Tokens.Duration.hover), value: hovering)
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
    let entries: () -> [MenuEntry]
    @State private var anchor = AnchorBox()

    var body: some View {
        TextButton(label: label, kind: kind, disabled: disabled, action: open)
            .background(AnchorMarker(box: anchor))
    }

    private func open() {
        anchor.showMenu(entries())
    }
}
