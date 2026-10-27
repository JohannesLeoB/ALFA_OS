import Design
import SwiftUI

struct RecipientRow<Trailing: View>: View {
    @Environment(\.appearance) private var appearance
    let label: Text
    let initials: String
    let title: String
    let detail: String
    let help: String
    @ViewBuilder let trailing: Trailing
    @State private var hovering = false

    var body: some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            label
                .designText(\.inkTertiary, size: Tokens.TextSize.small)
                .frame(width: CGFloat(Tokens.Size.recipientLabelColumn), alignment: .leading)
            Mark(size: .small) {
                if initials.isEmpty { Glyph.small(.person) } else { Text(verbatim: initials) }
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: title).designText().lineLimit(1).frame(height: CGFloat(SheetValues.conversationLine))
                if !detail.isEmpty {
                    Text(verbatim: detail).designText(\.inkTertiary, size: Tokens.TextSize.small).lineLimit(1)
                        .frame(height: CGFloat(SheetValues.conversationLine))
                }
            }
            Spacer(minLength: 0)
            trailing
        }
        .padding(.leading, CGFloat(Tokens.Spacing.step8))
        .padding(.trailing, CGFloat(Tokens.Spacing.step4))
        .frame(height: CGFloat(SheetValues.recipientRowHeight))
        .background(RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.field)).fill(hovering ? appearance.color(\.hover) : Color.clear))
        .contentShape(Rectangle())
        .help(Text(verbatim: help))
        .onHover { hovering = $0 }
    }
}

extension RecipientRow where Trailing == EmptyView {
    init(label: Text, initials: String, title: String, detail: String, help: String) {
        self.init(label: label, initials: initials, title: title, detail: detail, help: help) { EmptyView() }
    }
}
