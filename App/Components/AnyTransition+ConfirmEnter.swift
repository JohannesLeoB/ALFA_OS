import Design
import SwiftUI

private struct ConfirmEnter: ViewModifier {
    let amount: Double

    func body(content: Content) -> some View {
        content
            .opacity(1 - amount)
            .blur(radius: CGFloat(amount * Tokens.Size.confirmEnterBlur))
    }
}

extension AnyTransition {
    static var confirmEnter: AnyTransition {
        .modifier(active: ConfirmEnter(amount: 1), identity: ConfirmEnter(amount: 0))
    }
}
