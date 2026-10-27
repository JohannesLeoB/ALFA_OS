import Design
import Shell
import SwiftUI

struct CardStack<Item: Hashable, Card: View, Over: View, Note: View>: View {
    @Environment(\.appearance) private var appearance
    let order: [Item]
    let fanned: Bool
    @ViewBuilder let card: (Item, Int) -> Card
    @ViewBuilder let overview: () -> Over
    @ViewBuilder let note: () -> Note

    var body: some View {
        GeometryReader { proxy in
            let tops = CardStackEngine.tops(count: order.count)
            let shape = RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.card))
            ZStack(alignment: .top) {
                if order.isEmpty {
                    shape
                        .fill(appearance.color(\.lane))
                        .overlay(shape.strokeBorder(appearance.color(\.line), lineWidth: CGFloat(Tokens.Size.hairline)))
                        .accessibilityLabel(appearance.text("stack.empty"))
                }
                ForEach(Array(order.enumerated()), id: \.element) { index, item in
                    card(item, order.count - 1 - index)
                        .frame(width: proxy.size.width, height: max(0, proxy.size.height - CGFloat(tops[index])))
                        .offset(y: CGFloat(tops[index]))
                        .zIndex(Double(index))
                        .opacity(fanned ? 0 : 1)
                        .allowsHitTesting(!fanned)
                }
                if fanned {
                    overview()
                        .zIndex(Double(order.count + 1))
                }
                VStack {
                    Spacer(minLength: 0)
                    note()
                        .padding(.bottom, CGFloat(SheetValues.toastBottom))
                }
                .zIndex(Double(order.count + 2))
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .animation(appearance.ease(Tokens.Duration.stack, Tokens.Easing.stack), value: order)
        }
    }
}
