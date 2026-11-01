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
    var truncates = false
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
        disabled || !pressed || kind == .inverse ? 1 : Tokens.Scale.pressButton
    }

    private var height: CGFloat {
        CGFloat(size == .regular ? Tokens.Spacing.step28 : Tokens.Size.chipHeight)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
                glyph
                label.lineLimit(1).truncationMode(.tail)
            }
            .fixedSize(horizontal: !truncates, vertical: false)
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
         truncates: Bool = false, plate: KeyPath<Colors, ColorValue>? = nil, action: @escaping () -> Void) {
        self.init(label: label, kind: kind, size: size, disabled: disabled, pressed: pressed, truncates: truncates, plate: plate,
                  action: action) { EmptyView() }
    }
}

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
        .buttonStyle(PressScaleButtonStyle(scale: disabled || !pressed ? 1 : Tokens.Scale.pressButton))
        .disabled(disabled)
        .help(Text(verbatim: help))
        .accessibilityLabel(Text(verbatim: help))
        .onHover { hovering = $0 }
        .animation(appearance.ease(Tokens.Duration.hover), value: live)
        .animation(appearance.ease(Tokens.Duration.hover), value: plate)
    }
}

struct Glyph: View {
    let glyph: Icon
    var size = SheetValues.iconSize
    var stroke = SheetValues.iconStroke

    init(_ glyph: Icon, size: Double = SheetValues.iconSize, stroke: Double = SheetValues.iconStroke) {
        self.glyph = glyph
        self.size = size
        self.stroke = stroke
    }

    var body: some View {
        GlyphOutline(glyph: glyph)
            .stroke(style: StrokeStyle(lineWidth: CGFloat(stroke * size / SheetValues.iconBox), lineCap: .round, lineJoin: .round))
            .frame(width: CGFloat(size), height: CGFloat(size))
    }
}

extension Glyph {
    static func small(_ glyph: Icon) -> Glyph {
        Glyph(glyph, size: SheetValues.smallIcon, stroke: SheetValues.smallIconStroke)
    }

    static func tiny(_ glyph: Icon) -> Glyph {
        Glyph(glyph, size: SheetValues.tinyIcon, stroke: SheetValues.tinyIconStroke)
    }
}

struct GlyphOutline: Shape {
    let glyph: Icon

    func path(in rect: CGRect) -> Path {
        let scale = rect.width / CGFloat(SheetValues.iconBox)
        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + CGFloat(x) * scale, y: rect.minY + CGFloat(y) * scale)
        }
        var path = Path()
        for segment in glyph.path.segments {
            switch segment {
            case .move(let x, let y): path.move(to: point(x, y))
            case .line(let x, let y): path.addLine(to: point(x, y))
            case .cubic(let c1x, let c1y, let c2x, let c2y, let x, let y):
                path.addCurve(to: point(x, y), control1: point(c1x, c1y), control2: point(c2x, c2y))
            case .close: path.closeSubpath()
            }
        }
        return path
    }
}

struct PressScaleButtonStyle: ButtonStyle {
    let scale: Double

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? CGFloat(scale) : 1)
    }
}
