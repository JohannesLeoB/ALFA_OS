import SwiftUI
import AppTheme

/// Leinwandfläche (B-102): leer, mit Hinweis. Zeichnen der Stücke: B-203. Die Fläche ist Inhalt, kein Glas.
/// Tab schaltet alle Panels, aber nur, solange die Leinwand den Fokus hat.
struct CanvasView: View {
    var shell: ShellState

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @FocusState private var hasFocus: Bool

    var body: some View {
        VStack(spacing: theme.space(.s2)) {
            Text("Leinwand")
                .font(theme.text(.caption).font)
            Text("Zieh etwas hierher oder drücke ⌘V")
                .font(theme.text(.body).font)
        }
        .foregroundStyle(theme.color(.textMuted, scheme))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.color(.background, scheme).ignoresSafeArea(edges: .top))
        .contentShape(Rectangle())
        .onTapGesture { hasFocus = true }
        .focusable()
        .focusEffectDisabled()
        .focused($hasFocus)
        .onKeyPress(.tab) {
            guard hasFocus else { return .ignored }
            shell.togglePanels()
            return .handled
        }
        .onAppear { hasFocus = true }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Leinwand, leer")
    }
}
