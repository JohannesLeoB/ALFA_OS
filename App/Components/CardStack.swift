import Design
import Shell
import SwiftUI

struct CardStack<Item: Hashable, Card: View, Over: View>: View {
    @Environment(\.appearance) private var appearance
    let order: [Item]
    let overviewOpen: Bool
    var spreads = false
    var top = Tokens.Spacing.step8
    @ViewBuilder let card: (Item, Int) -> Card
    @ViewBuilder let overview: () -> Over

    var body: some View {
        GeometryReader { proxy in
            let spread = spreads && overviewOpen
            let tops = spread ? CardStackEngine.spreadTops(count: order.count) : CardStackEngine.tops(count: order.count, start: top)
            let shape = RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.card))
            ZStack(alignment: .top) {
                if order.isEmpty {
                    shape
                        .fill(appearance.color(\.lane))
                        .overlay(shape.strokeBorder(appearance.color(\.line), lineWidth: CGFloat(Tokens.Size.hairline)))
                        .accessibilityLabel(appearance.text("stack.empty"))
                }
                ZStack(alignment: .top) {
                    ForEach(Array(order.enumerated()), id: \.element) { index, item in
                        card(item, order.count - 1 - index)
                            .frame(width: max(0, proxy.size.width - 2 * CGFloat(Tokens.Size.cardInset)),
                                   height: spread ? CGFloat(Tokens.Size.headerHeight) : max(0, proxy.size.height - CGFloat(tops[index])))
                            .offset(y: CGFloat(tops[index]))
                            .zIndex(Double(index))
                            .opacity(overviewOpen ? 0 : 1)
                            .allowsHitTesting(!overviewOpen)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                .animation(appearance.ease(Tokens.Transition.stack), value: overviewOpen)
                .zIndex(Double(Tokens.Layer.lane))
                if overviewOpen {
                    overview()
                        .zIndex(Double(Tokens.Layer.inLaneOverview))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .animation(appearance.ease(Tokens.Transition.stack), value: order)
        }
    }
}
