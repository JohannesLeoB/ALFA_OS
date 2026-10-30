import Design
import Shell
import SwiftUI

struct CardStack<Item: Hashable, Card: View, Over: View>: View {
    @Environment(\.appearance) private var appearance
    let order: [Item]
    let overviewOpen: Bool
    @ViewBuilder let card: (Item, Int) -> Card
    @ViewBuilder let overview: () -> Over

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
                ZStack(alignment: .top) {
                    ForEach(Array(order.enumerated()), id: \.element) { index, item in
                        card(item, order.count - 1 - index)
                            .frame(width: max(0, proxy.size.width - 2 * CGFloat(Tokens.Size.cardInset)),
                                   height: max(0, proxy.size.height - CGFloat(tops[index])))
                            .offset(y: CGFloat(tops[index]))
                            .zIndex(Double(index))
                            .opacity(overviewOpen ? 0 : 1)
                            .animation(overviewOpen ? appearance.ease(Tokens.Duration.toggle, SheetValues.cssEase)
                                       : appearance.ease(Tokens.Duration.overviewDelay, SheetValues.cssEase, delay: Tokens.Duration.reelStagger),
                                       value: overviewOpen)
                            .offset(y: overviewOpen ? CGFloat(Tokens.Spacing.step8) : 0)
                            .animation(appearance.ease(Tokens.Duration.stackLift), value: overviewOpen)
                            .allowsHitTesting(!overviewOpen)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
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
