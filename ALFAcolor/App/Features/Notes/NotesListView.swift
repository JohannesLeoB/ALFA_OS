import SwiftUI
import AppTheme
import ALFAcolorCore
import BoardModel

/// The notes of the items: with one item, each note with its author, its date, a done mark, and buttons to edit and
/// delete it. With several items the list is not shown, and the field adds one note to each of them, as one step.
/// It serves the popover of a mark and the inspector section. Every change is one undo step.
struct NotesListView: View {
    let store: BoardStore
    let itemIDs: [ItemID]

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @State private var newText = ""
    @State private var refused = false
    @State private var editingID: UUID?
    @State private var editText = ""

    /// The one item whose notes are listed. nil when there are several, or none.
    private var single: ItemID? { itemIDs.count == 1 ? itemIDs[0] : nil }

    private var notes: [ItemNote] {
        guard let single else { return [] }
        return store.item(single)?.notes ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.space(.s2)) {
            if let single {
                if notes.isEmpty {
                    Text(LocalizedStringKey("note.empty"))
                        .themeText(theme.text(.control))
                        .foregroundStyle(theme.color(.textMuted, scheme))
                }
                ForEach(notes) { note in
                    row(note, on: single)
                }
            } else if itemIDs.count > 1 {
                Text(LocalizedStringKey("note.multi"))
                    .themeText(theme.text(.caption))
                    .foregroundStyle(theme.color(.textMuted, scheme))
            }
            HStack(spacing: theme.space(.s1)) {
                TextField(String(localized: "note.placeholder"), text: $newText)
                    .textFieldStyle(.plain)
                    .themeText(theme.text(.control))
                    .onSubmit(add)
                Button(String(localized: "note.add"), action: add)
                    .buttonStyle(.plain)
                    .themeText(theme.text(.control))
                    .disabled(newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || itemIDs.isEmpty)
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

    private func row(_ note: ItemNote, on itemID: ItemID) -> some View {
        VStack(alignment: .leading, spacing: theme.space(.s1)) {
            if editingID == note.id {
                TextField("", text: $editText)
                    .textFieldStyle(.plain)
                    .themeText(theme.text(.control))
                    .onSubmit { commitEdit(note, on: itemID) }
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
                    _ = try? store.perform(noteResolve: note.id, resolved: !note.resolved, on: itemID)
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
                    _ = try? store.perform(noteDelete: note.id, on: itemID)
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

    /// Adds the typed note to each item. A refused note keeps its text.
    private func add() {
        let note = ItemNote(text: newText, author: .user, createdAt: .now)
        do {
            guard try store.perform(noteAdd: note, to: itemIDs) else { return }
            newText = ""
            refused = false
        } catch {
            refused = true
        }
    }

    /// Ends the edit of a note. An empty text is refused and the old text stays.
    private func commitEdit(_ note: ItemNote, on itemID: ItemID) {
        _ = try? store.perform(noteEdit: note.id, text: editText, on: itemID)
        editingID = nil
    }
}
