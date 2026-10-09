import SwiftUI
import AppTheme
import BoardModel

/// The text of an item that is being edited, and the interaction that ends the edit.
struct TextEditing {
    let text: Binding<String>
    let interaction: CanvasInteraction
}

/// The text field in place of the text of a note or a text item, in the same style. It takes the focus when it appears.
/// Escape and losing the focus end the edit and keep the text.
struct TextEditorBody: View {
    @Binding var text: String
    let role: TextRole
    /// A note has room around its text; a free text does not.
    let padded: Bool
    var interaction: CanvasInteraction?

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @FocusState private var focused: Bool

    var body: some View {
        TextEditor(text: $text)
            .themeText(theme.text(role.token))
            .foregroundStyle(theme.color(.text, scheme))
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .padding(padded ? theme.space(.s2) : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .focused($focused)
            .onAppear { focused = true }
            .onChange(of: focused) { was, now in
                if was && !now { interaction?.commitEdit() }
            }
            .onKeyPress(.escape) {
                interaction?.escape()
                return .handled
            }
    }
}
