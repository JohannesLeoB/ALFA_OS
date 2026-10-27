import Design
import Shell
import SwiftUI

struct Spinner: View {
    @Environment(\.appearance) private var appearance
    var side = Tokens.Size.symbolSize
    var arc = SheetValues.spinnerArc
    var stroke = Tokens.Size.hairline
    var duration = Tokens.Duration.thinking
    var tone: KeyPath<Colors, ColorValue>? = \.ink
    var track: KeyPath<Colors, ColorValue>?
    var round = false
    @State private var turn = 0.0

    var body: some View {
        let line = CGFloat(stroke)
        let style = tone.map { AnyShapeStyle(appearance.color($0)) } ?? AnyShapeStyle(.foreground)
        ZStack {
            if let track {
                Circle().strokeBorder(appearance.color(track), lineWidth: line)
            }
            Circle()
                .inset(by: line / 2)
                .trim(from: 0, to: CGFloat(arc))
                .stroke(style, style: StrokeStyle(lineWidth: line, lineCap: round ? .round : .butt))
        }
        .frame(width: CGFloat(side), height: CGFloat(side))
        .rotationEffect(.degrees(turn))
        .task {
            guard !appearance.still else { return }
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) { turn = SheetValues.fullTurn }
        }
    }
}
