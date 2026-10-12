import SwiftUI
import AppTheme
import ALFAcolorCore
import BoardModel

/// The small field that the comment tool shows at the place of a press. Enter or "Fertig" adds the note, an empty
/// text adds none, and Escape discards the draft. A refused note keeps the text and says why.
struct NoteDraftField: View {
    let interaction: CanvasInteraction

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @State private var text = ""
    @State private var refused = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: theme.space(.s1)) {
            HStack(spacing: theme.space(.s1)) {
                TextField(String(localized: "note.placeholder"), text: $text)
                    .textFieldStyle(.plain)
                    .themeText(theme.text(.control))
                    .frame(width: theme.grid(20))
                    .focused($focused)
                    .onSubmit(finish)
                    .onExitCommand { interaction.cancelNoteDraft() }
                Button(String(localized: "note.done"), action: finish)
                    .buttonStyle(.plain)
                    .themeText(theme.text(.control))
            }
            if refused {
                Text(String(localized: "note.tooMany"))
                    .themeText(theme.text(.caption))
                    .foregroundStyle(theme.color(.textMuted, scheme))
            }
        }
        .padding(.horizontal, theme.space(.s2))
        .padding(.vertical, theme.space(.s1))
        .background(Capsule().fill(theme.color(.surfaceContent, scheme)))
        .foregroundStyle(theme.color(.text, scheme))
        .onAppear { focused = true }
    }

    /// Adds the note. The field stays open with its text when the item is full.
    private func finish() {
        do {
            try interaction.finishNoteDraft(text: text)
            text = ""
            refused = false
        } catch {
            refused = true
        }
    }
}
