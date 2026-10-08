import SwiftUI
import AppTheme

/// Canvas area: empty, with a hint. The area is content, not glass.
/// Tab toggles all panels, but only while the canvas has focus.
struct CanvasView: View {
    var shell: ShellState

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @FocusState private var hasFocus: Bool

    var body: some View {
        VStack(spacing: theme.space(.s2)) {
            Text("canvas.title")
                .font(theme.text(.caption).font)
            Text("canvas.hint")
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
        .accessibilityLabel("canvas.accessibility")
    }
}
