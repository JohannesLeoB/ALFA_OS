import Design
import SwiftUI

private struct RowPill: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(width: CGFloat(Tokens.Size.confirmPillWidth), alignment: .trailing)
            .padding(.trailing, -CGFloat(Tokens.Size.confirmPillOffset))
    }
}

extension View {
    func rowPill() -> some View {
        modifier(RowPill())
    }
}
