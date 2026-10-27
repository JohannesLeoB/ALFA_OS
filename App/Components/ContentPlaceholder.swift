import Design
import Shell
import SwiftUI

struct ContentPlaceholder<Glyph: View, Action: View>: View {
    enum Kind {
        case loading
        case permissionRequired
        case failed
        case noResults
        case empty
    }

    @Environment(\.appearance) private var appearance
    let kind: Kind
    var title: Text?
    let text: Text
    @ViewBuilder let glyph: Glyph
    @ViewBuilder let action: Action

    var body: some View {
        let symbol = CGFloat(Tokens.Size.symbolSize)
        VStack(spacing: CGFloat(Tokens.Spacing.step12)) {
            ZStack {
                if kind == .loading { Spinner() } else { glyph }
            }
            .foregroundStyle(appearance.color(\.inkTertiary))
            .frame(width: symbol, height: symbol)
            .ring(Circle(), appearance.color(\.lineStrong))
            if let title {
                title
                    .font(.face(Tokens.TextSize.body, weight: Tokens.Weight.medium))
                    .foregroundStyle(appearance.color(\.ink))
                    .lineHeight(Tokens.LineHeight.body * Tokens.TextSize.body, size: Tokens.TextSize.body)
                    .frame(maxWidth: CGFloat(SheetValues.stateTextWidth))
            }
            text
                .font(.face(Tokens.TextSize.body))
                .foregroundStyle(appearance.color(\.inkTertiary))
                .lineHeight(Tokens.LineHeight.body * Tokens.TextSize.body, size: Tokens.TextSize.body)
                .frame(maxWidth: CGFloat(SheetValues.stateTextWidth))
            action
        }
        .multilineTextAlignment(.center)
        .padding(CGFloat(Tokens.Spacing.step24))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension ContentPlaceholder where Glyph == EmptyView, Action == EmptyView {
    init(loading text: Text) {
        self.init(kind: .loading, text: text, glyph: { EmptyView() }, action: { EmptyView() })
    }
}
