import Design
import SwiftUI

enum NoticeKind {
    case failure
    case success
    case warning
}

struct Notice<Glyph: View, Actions: View>: View {
    @Environment(\.appearance) private var appearance
    let kind: NoticeKind
    let title: Text
    let text: Text?
    var onSheet = false
    @ViewBuilder let glyph: Glyph
    @ViewBuilder let actions: Actions

    private var symbolTone: KeyPath<Colors, ColorValue> {
        if onSheet { return \.sheetInkSecondary }
        switch kind {
        case .failure: return \.signal
        case .success: return \.ink
        case .warning: return \.inkSecondary
        }
    }

    var body: some View {
        let symbol = CGFloat(Tokens.Size.symbolSize)
        HStack(alignment: .top, spacing: CGFloat(Tokens.Spacing.step20)) {
            glyph
                .foregroundStyle(appearance.color(symbolTone))
                .frame(width: symbol, height: symbol)
                .ring(Circle(), appearance.color(onSheet ? \.sheetLineStrong : symbolTone))
            VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step2)) {
                title
                    .font(.face(Tokens.TextSize.body, weight: Tokens.Weight.medium))
                    .foregroundStyle(appearance.color(onSheet ? \.sheetInk : \.ink))
                    .lineHeight(Tokens.LineHeight.notice, size: Tokens.TextSize.body)
                if let text {
                    text
                        .font(.face(Tokens.TextSize.body))
                        .foregroundStyle(appearance.color(onSheet ? \.sheetInkTertiary : \.inkTertiary))
                        .lineHeight(Tokens.LineHeight.notice, size: Tokens.TextSize.body)
                }
                HStack(spacing: CGFloat(Tokens.Spacing.step8)) { actions }
                    .padding(.top, CGFloat(Tokens.Spacing.step8))
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, CGFloat(Tokens.Spacing.step4))
        }
        .padding(CGFloat(Tokens.Spacing.step8))
        .background(
            RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.notice))
                .fill(appearance.color(onSheet ? \.sheetWell : \.well))
        )
    }
}
