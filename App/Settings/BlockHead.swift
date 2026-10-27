import Design
import SwiftUI

struct BlockHead: View {
    @Environment(\.appearance) private var appearance
    let key: String

    var body: some View {
        appearance.text(key)
            .font(.face(Tokens.TextSize.small))
            .foregroundStyle(appearance.color(\.inkTertiary))
            .padding(.horizontal, CGFloat(Tokens.Spacing.step16))
            .padding(.bottom, CGFloat(Tokens.Spacing.step8))
            .frame(maxWidth: .infinity, minHeight: CGFloat(Tokens.Spacing.step36), alignment: .bottomLeading)
    }
}

struct BlockNote: View {
    @Environment(\.appearance) private var appearance
    let text: Text

    var body: some View {
        text
            .font(.face(Tokens.TextSize.small))
            .foregroundStyle(appearance.color(\.inkTertiary))
            .lineHeight(Tokens.LineHeight.small, size: Tokens.TextSize.small)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, CGFloat(Tokens.Spacing.step16))
            .padding(.vertical, CGFloat(Tokens.Spacing.step8))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
