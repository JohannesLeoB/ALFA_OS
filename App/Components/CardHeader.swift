import Design
import SwiftUI

struct CardHeader<Mark: View, Title: View, Meta: View, Trailing: View>: View {
    let front: Bool
    let ink: Color
    @ViewBuilder let mark: Mark
    @ViewBuilder let title: Title
    @ViewBuilder let meta: Meta
    @ViewBuilder let trailing: Trailing

    var body: some View {
        let side = CGFloat(Tokens.Size.symbolSize)
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            mark
                .typeStyle(Tokens.TextStyle.mark)
                .lineLimit(1)
                .frame(width: side, height: side)
                .overlay(Circle().strokeBorder(ink.opacity(Tokens.Opacity.ringOnMark), lineWidth: CGFloat(Tokens.Size.hairline)))
                .padding(.trailing, CGFloat(Tokens.Spacing.step12))
            title.layoutPriority(1)
            meta
            trailing
        }
        .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
        .frame(height: CGFloat(Tokens.Spacing.step44))
        .overlay(alignment: .bottom) {
            if front { Hairline() }
        }
    }
}
