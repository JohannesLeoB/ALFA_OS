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
    case inverse
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
    var plate: KeyPath<Colors, ColorValue>?
    let action: () -> Void
    @ViewBuilder let glyph: Glyph
    @State private var hovering = false

    private var fill: Color {
        if let plate { return appearance.color(plate) }
        switch kind {
        case .accent: return appearance.color(\.inverse)
        case .sheet: return appearance.color(\.sheet)
        case .inverse: return appearance.color(hovering && !disabled ? \.inverseHot : \.inverseField)
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
        case .inverse: appearance.color(\.onInverse)
        }
    }

    private var ringColor: Color? {
        switch kind {
        case .accent, .plain, .inverse: nil
        case .neutral, .quiet: appearance.color(\.lineStrong)
        case .signal: appearance.color(\.signal)
        case .sheet: appearance.color(\.sheetLineStrong)
        }
    }

    private var style: TypeStyle {
        kind == .inverse ? Tokens.TextStyle.body : Tokens.TextStyle.control
    }

    private var scale: Double {
        disabled || !pressed || kind == .inverse ? 1 : SheetValues.pressScale
    }

    private var height: CGFloat {
        CGFloat(size == .regular ? Tokens.Spacing.step28 : Tokens.Size.chipHeight)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
                glyph
                label.lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)
            .typeStyle(style)
            .foregroundStyle(foreground)
            .padding(.leading, CGFloat(Glyph.self == EmptyView.self ? Tokens.Spacing.step12 : Tokens.Spacing.step8))
            .padding(.trailing, CGFloat(Tokens.Spacing.step12))
            .frame(height: height)
            .background(Capsule().fill(fill))
            .ring(Pill(), ringColor)
            .contentShape(Capsule())
            .opacity(disabled ? Tokens.Opacity.disabled : 1)
        }
        .buttonStyle(PressScaleButtonStyle(scale: scale))
        .disabled(disabled)
        .onHover { hovering = $0 }
        .animation(appearance.ease(Tokens.Duration.hover), value: hovering)
    }
}

extension TextButton where Glyph == EmptyView {
    init(label: Text, kind: TextButtonKind = .neutral, size: TextButtonSize = .regular, disabled: Bool = false, pressed: Bool = true,
         plate: KeyPath<Colors, ColorValue>? = nil, action: @escaping () -> Void) {
        self.init(label: label, kind: kind, size: size, disabled: disabled, pressed: pressed, plate: plate, action: action) { EmptyView() }
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
