import SwiftUI
import AppTheme
import ALFAcolorCore
import BoardModel

/// The notes of one item: each with its author, its date, a done mark, and buttons to edit and delete it, and a field
/// that adds a note. It serves the popover of a mark and the inspector section. Every change is one undo step.
struct NotesListView: View {
    let store: BoardStore
    let itemID: ItemID

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @State private var newText = ""
    @State private var refused = false
    @State private var editingID: UUID?
    @State private var editText = ""

    private var notes: [ItemNote] { store.item(itemID)?.notes ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.space(.s2)) {
            if notes.isEmpty {
                Text(LocalizedStringKey("note.empty"))
                    .themeText(theme.text(.control))
                    .foregroundStyle(theme.color(.textMuted, scheme))
            }
            ForEach(notes) { note in
                row(note)
            }
            HStack(spacing: theme.space(.s1)) {
                TextField(String(localized: "note.placeholder"), text: $newText)
                    .textFieldStyle(.plain)
                    .themeText(theme.text(.control))
                    .onSubmit(add)
                Button(String(localized: "note.add"), action: add)
                    .buttonStyle(.plain)
                    .themeText(theme.text(.control))
                    .disabled(newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if refused {
                Text(LocalizedStringKey("note.tooMany"))
                    .themeText(theme.text(.caption))
                    .foregroundStyle(theme.color(.textMuted, scheme))
            }
        }
        .padding(theme.space(.s3))
        .frame(width: theme.grid(40), alignment: .leading)
        .foregroundStyle(theme.color(.text, scheme))
    }

    private func row(_ note: ItemNote) -> some View {
        VStack(alignment: .leading, spacing: theme.space(.s1)) {
            if editingID == note.id {
                TextField("", text: $editText)
                    .textFieldStyle(.plain)
                    .themeText(theme.text(.control))
                    .onSubmit { commitEdit(note) }
                    .onExitCommand { editingID = nil }
            } else {
                Text(note.text)
                    .themeText(theme.text(.control))
                    .strikethrough(note.resolved)
                    .foregroundStyle(note.resolved ? theme.color(.textMuted, scheme) : theme.color(.text, scheme))
            }
            HStack(spacing: theme.space(.s2)) {
                Text(note.author == .user ? LocalizedStringKey("note.author.user") : LocalizedStringKey("note.author.assistant"))
                Text(note.createdAt, style: .date)
                Spacer(minLength: 0)
                Button {
                    try? store.perform(noteResolve: note.id, resolved: !note.resolved, on: itemID)
                } label: {
                    Image(systemName: note.resolved ? "checkmark.circle.fill" : "circle")
                }
                .help(String(localized: "note.resolved"))
                Button {
                    editText = note.text
                    editingID = note.id
                } label: {
                    Image(systemName: "pencil")
                }
                .help(String(localized: "note.edit"))
                Button {
                    try? store.perform(noteDelete: note.id, on: itemID)
                } label: {
                    Image(systemName: "trash")
                }
                .help(String(localized: "note.delete"))
            }
            .buttonStyle(.plain)
            .themeText(theme.text(.caption))
            .foregroundStyle(theme.color(.textMuted, scheme))
        }
    }

    /// Adds the typed note to the item. A refused note keeps its text.
    private func add() {
        let text = newText
        let note = ItemNote(text: text, author: .user, createdAt: .now)
        do {
            guard try store.perform(noteAdd: note, to: [itemID]) else { return }
            newText = ""
            refused = false
        } catch {
            refused = true
        }
    }

    /// Ends the edit of a note. An empty text is refused and the old text stays.
    private func commitEdit(_ note: ItemNote) {
        _ = try? store.perform(noteEdit: note.id, text: editText, on: itemID)
        editingID = nil
    }
}
