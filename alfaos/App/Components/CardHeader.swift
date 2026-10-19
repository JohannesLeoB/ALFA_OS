import ShellCore
import SwiftUI

struct CardHeader<Mark: View, Title: View, Meta: View, Trailing: View>: View {
    let front: Bool
    let ink: Color
    @ViewBuilder let mark: Mark
    @ViewBuilder let title: Title
    @ViewBuilder let meta: Meta
    @ViewBuilder let trailing: Trailing

    var body: some View {
        let side = CGFloat(Design.Size.symbolSize)
        HStack(spacing: CGFloat(Design.Size.headGapList)) {
            mark
                .font(.face(Design.TextSize.small, weight: Design.Weight.medium))
                .lineLimit(1)
                .frame(width: side, height: side)
                .overlay(Circle().strokeBorder(ink.opacity(Design.Opacity.ringOnMark), lineWidth: CGFloat(Design.Size.hairline)))
                .padding(.trailing, CGFloat(Design.Spacing.step12))
            title.layoutPriority(1)
            meta
            trailing
        }
        .padding(.horizontal, CGFloat(Design.Size.headPadRight))
        .frame(height: CGFloat(Design.Size.headerHeight))
        .overlay(alignment: .bottom) {
            if front { Hairline() }
        }
    }
}
