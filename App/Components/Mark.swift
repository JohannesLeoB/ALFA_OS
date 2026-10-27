import Design
import Shell
import SwiftUI

enum MarkSize {
    case regular
    case small
}

enum MarkFill {
    case rest
    case filled
    case signal
}

struct Mark<Content: View>: View {
    @Environment(\.appearance) private var appearance
    var size = MarkSize.regular
    var fill = MarkFill.rest
    var inverted = false
    var tone: KeyPath<Colors, ColorValue>?
    @ViewBuilder let content: Content

    private var ink: InkSet { .of(inverted) }

    private var background: Color {
        switch fill {
        case .rest: size == .small ? appearance.color(\.lane) : Color.clear
        case .filled: appearance.color(ink.primary)
        case .signal: appearance.color(\.signal)
        }
    }

    private var foreground: Color {
        switch fill {
        case .rest: appearance.color(tone ?? ink.secondary)
        case .filled: appearance.color(inverted ? \.ink : \.lane)
        case .signal: appearance.color(\.onSignal)
        }
    }

    var body: some View {
        let side = CGFloat(size == .regular ? Tokens.Size.symbolSize : Tokens.Size.chipHeight)
        content
            .font(.face(Tokens.TextSize.small, weight: Tokens.Weight.medium))
            .tracking(CGFloat(SheetValues.markTracking * Tokens.TextSize.small))
            .lineLimit(1)
            .foregroundStyle(foreground)
            .frame(width: side, height: side)
            .background(Circle().fill(background))
            .ring(Circle(), fill == .rest ? appearance.color(ink.line) : nil)
    }
}
