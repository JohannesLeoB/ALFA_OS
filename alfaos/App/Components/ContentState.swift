import ShellCore
import SwiftUI

enum ContentStateKind {
    case loading
    case permissionRequired
    case failed
    case noResults
    case empty
}

struct ContentState<Glyph: View, Action: View>: View {
    @Environment(\.design) private var design
    let kind: ContentStateKind
    var title: Text?
    let text: Text
    @ViewBuilder let glyph: Glyph
    @ViewBuilder let action: Action

    var body: some View {
        let symbol = CGFloat(Design.Size.symbolSize)
        VStack(spacing: CGFloat(Design.Spacing.step12)) {
            ZStack {
                if kind == .loading { Spinner() } else { glyph }
            }
            .foregroundStyle(design.color(\.inkTertiary))
            .frame(width: symbol, height: symbol)
            .ring(Circle(), design.color(\.lineStrong))
            if let title {
                title
                    .font(.face(Design.TextSize.body, weight: Design.Weight.medium))
                    .foregroundStyle(design.color(\.ink))
                    .lineHeight(Design.LineHeight.body * Design.TextSize.body, size: Design.TextSize.body)
                    .frame(maxWidth: CGFloat(SheetValues.stateTextWidth))
            }
            text
                .font(.face(Design.TextSize.body))
                .foregroundStyle(design.color(\.inkTertiary))
                .lineHeight(Design.LineHeight.body * Design.TextSize.body, size: Design.TextSize.body)
                .frame(maxWidth: CGFloat(SheetValues.stateTextWidth))
            action
        }
        .multilineTextAlignment(.center)
        .padding(CGFloat(Design.Spacing.step24))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension ContentState where Glyph == EmptyView, Action == EmptyView {
    init(loading text: Text) {
        self.init(kind: .loading, text: text, glyph: { EmptyView() }, action: { EmptyView() })
    }
}

struct Spinner: View {
    @Environment(\.design) private var design
    @Environment(\.hairline) private var hairline
    @Environment(\.accessibilityReduceMotion) private var reduced
    @State private var turn = 0.0

    var body: some View {
        Circle()
            .trim(from: 0, to: CGFloat(SheetValues.spinnerArc))
            .stroke(design.color(\.ink), lineWidth: hairline)
            .frame(width: CGFloat(Design.Size.symbolSize), height: CGFloat(Design.Size.symbolSize))
            .rotationEffect(.degrees(turn))
            .task {
                guard !reduced else { return }
                withAnimation(.linear(duration: Design.Duration.thinking).repeatForever(autoreverses: false)) { turn = 360 }
            }
    }
}
