import ShellCore
import SwiftUI

enum NoticeKind {
    case failure
    case success
    case info
    case warning
}

struct Notice<Glyph: View, Actions: View>: View {
    @Environment(\.design) private var design
    let kind: NoticeKind
    let title: Text
    let text: Text
    var onSheet = false
    @ViewBuilder let glyph: Glyph
    @ViewBuilder let actions: Actions

    private var symbolTone: KeyPath<DesignColors, RGB> {
        if onSheet { return \.sheetInkSecondary }
        switch kind {
        case .failure: return \.signal
        case .success: return \.ink
        case .info, .warning: return \.inkSecondary
        }
    }

    var body: some View {
        let symbol = CGFloat(Design.Size.symbolSize)
        HStack(alignment: .top, spacing: CGFloat(Design.Spacing.step20)) {
            glyph
                .foregroundStyle(design.color(symbolTone))
                .frame(width: symbol, height: symbol)
                .ring(Circle(), design.color(onSheet ? \.sheetLineStrong : symbolTone))
            VStack(alignment: .leading, spacing: 0) {
                title
                    .font(onSheet ? Font(Typeface.sheet(size: Design.TextSize.body, weight: .medium))
                          : .face(Design.TextSize.body, weight: Design.Weight.medium))
                    .foregroundStyle(design.color(onSheet ? \.sheetInk : \.ink))
                    .lineHeight(Design.LineHeight.notice, size: Design.TextSize.body, sheet: onSheet)
                text
                    .font(onSheet ? Font(Typeface.sheet(size: Design.TextSize.body)) : .face(Design.TextSize.body))
                    .foregroundStyle(design.color(onSheet ? \.sheetInkTertiary : \.inkTertiary))
                    .lineHeight(Design.LineHeight.notice, size: Design.TextSize.body, sheet: onSheet)
                HStack(spacing: CGFloat(Design.Spacing.step8)) { actions }
                    .padding(.top, CGFloat(Design.Spacing.step8))
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, CGFloat(Design.Spacing.step4))
        }
        .padding(CGFloat(Design.Spacing.step8))
        .background(
            RoundedRectangle(cornerRadius: CGFloat(Design.Radius.notice))
                .fill(design.color(onSheet ? \.sheetWell : \.well))
        )
    }
}
