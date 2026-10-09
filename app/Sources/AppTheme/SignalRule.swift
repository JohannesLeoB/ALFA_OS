import SwiftUI

public extension View {
    /// A coral line under the view, when `shown`. Coral is too weak as text on white, so the signal is a line and the text stays ink.
    func signalRule(_ shown: Bool) -> some View {
        modifier(SignalRule(shown: shown))
    }
}

/// The coral line under a view that signals a state.
struct SignalRule: ViewModifier {
    let shown: Bool
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if shown {
                Rectangle().fill(theme.color(.coral, scheme)).frame(height: 1)
            }
        }
    }
}
