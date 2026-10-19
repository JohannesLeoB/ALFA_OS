import ShellCore
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
    @Environment(\.design) private var design
    var size = MarkSize.regular
    var fill = MarkFill.rest
    var inverted = false
    var tone: KeyPath<DesignColors, RGB>?
    @ViewBuilder let content: Content

    private var ink: InkSet { .of(inverted) }

    private var background: Color {
        switch fill {
        case .rest: size == .small ? design.color(\.lane) : Color.clear
        case .filled: design.color(ink.primary)
        case .signal: design.color(\.signal)
        }
    }

    private var foreground: Color {
        switch fill {
        case .rest: design.color(tone ?? ink.secondary)
        case .filled: design.color(inverted ? \.ink : \.lane)
        case .signal: design.color(\.onSignal)
        }
    }

    var body: some View {
        let side = CGFloat(size == .regular ? Design.Size.symbolSize : Design.Size.chipHeight)
        content
            .font(.face(Design.TextSize.small, weight: Design.Weight.medium))
            .lineLimit(1)
            .foregroundStyle(foreground)
            .frame(width: side, height: side)
            .background(Circle().fill(background))
            .ring(Circle(), fill == .rest ? design.color(ink.line) : nil)
    }
}
