import SwiftUI

extension View {
    func scrolledSignal(_ scrolled: Binding<Bool>) -> some View {
        onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y > 0 } action: { _, now in scrolled.wrappedValue = now }
    }
}
