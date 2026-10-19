import ShellCore
import SwiftUI

struct MessageRow<Mark: View, Content: View>: View {
    let fill: Color
    let ring: Color?
    let separated: Bool
    @ViewBuilder let mark: Mark
    @ViewBuilder let content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row))
        HStack(alignment: .top, spacing: CGFloat(SheetValues.rowSpacing)) {
            mark
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.top, CGFloat(Design.Spacing.step4))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, CGFloat(SheetValues.rowPadding))
        .padding(.horizontal, CGFloat(Design.Spacing.step8))
        .background(shape.fill(fill))
        .ring(shape, ring)
        .overlay(alignment: .bottom) {
            if separated {
                Hairline()
                    .padding(.leading, CGFloat(SheetValues.rowSeparatorInset))
                    .padding(.trailing, CGFloat(Design.Spacing.step8))
            }
        }
    }
}
