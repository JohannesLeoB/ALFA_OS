import Design
import SwiftUI

struct DeckRow<Mark: View, Label: View>: View {
    var trailing = Deck.toggleRoom
    @ViewBuilder let mark: Mark
    @ViewBuilder let label: Label

    var body: some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            mark.padding(.trailing, CGFloat(Tokens.Spacing.step12))
            label
        }
        .padding(.leading, Deck.inset)
        .padding(.trailing, trailing)
        .frame(height: Deck.row)
    }
}
