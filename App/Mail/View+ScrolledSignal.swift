import Design
import SwiftUI

private struct ScrolledSignal: ViewModifier {
    @Binding var scrolled: Bool
    @State private var rest: Task<Void, Never>?

    func body(content: Content) -> some View {
        content.onScrollGeometryChange(for: Double.self) { Double($0.contentOffset.y) } action: { old, now in
            rest?.cancel()
            guard now > 0, now != old else {
                if now <= 0 { scrolled = false }
                return
            }
            scrolled = true
            rest = Task { @MainActor in
                try? await Task.sleep(for: .seconds(Tokens.Duration.scrollLineRest))
                if !Task.isCancelled { scrolled = false }
            }
        }
    }
}

extension View {
    func scrolledSignal(_ scrolled: Binding<Bool>) -> some View {
        modifier(ScrolledSignal(scrolled: scrolled))
    }
}
