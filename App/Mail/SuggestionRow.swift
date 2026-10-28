import Design
import Mail
import SwiftUI

extension Suggestion {
    var entry: String { name.isEmpty ? address : "\"" + name + "\" <" + address + ">" }
}

struct SuggestionRow: View {
    @Environment(\.appearance) private var appearance
    let item: Suggestion
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: CGFloat(SheetValues.suggestionColumnGap)) {
                Mark(size: .small) {
                    if item.initials.isEmpty { Glyph.small(.person) } else { Text(verbatim: item.initials) }
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: item.name.isEmpty ? item.shown : item.name).designText().lineLimit(1)
                        .frame(height: CGFloat(SheetValues.conversationLine))
                    Text(verbatim: item.shown).designText(\.inkTertiary, size: Tokens.TextSize.small).lineLimit(1)
                        .frame(height: CGFloat(SheetValues.conversationLine))
                }
                Spacer(minLength: 0)
                appearance.text(item.tag.key).designText(\.inkTertiary, size: Tokens.TextSize.small).lineLimit(1)
            }
            .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
            .frame(height: CGFloat(Tokens.Size.suggestionRowHeight))
            .background(RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.field)).fill(hovering ? appearance.color(\.hover) : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(Text(verbatim: item.address))
        .onHover { hovering = $0 }
    }
}
