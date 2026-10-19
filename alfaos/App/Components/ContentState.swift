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
                if kind != .loading { glyph }
            }
            .foregroundStyle(design.color(\.inkTertiary))
            .frame(width: symbol, height: symbol)
            .ring(Circle(), design.color(\.lineStrong))
            if let title {
                title
                    .font(.system(size: CGFloat(Design.TextSize.body), weight: .design(Design.Weight.medium)))
                    .foregroundStyle(design.color(\.ink))
                    .lineHeight(Design.LineHeight.body * Design.TextSize.body, size: Design.TextSize.body)
            }
            text
                .font(.system(size: CGFloat(Design.TextSize.body)))
                .foregroundStyle(design.color(\.inkTertiary))
                .lineHeight(Design.LineHeight.body * Design.TextSize.body, size: Design.TextSize.body)
            action
        }
        .multilineTextAlignment(.center)
        .padding(CGFloat(Design.Spacing.step24))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
