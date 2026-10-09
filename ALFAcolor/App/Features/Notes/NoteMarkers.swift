import SwiftUI
import AppTheme
import ALFAcolorCore
import BoardModel

/// The marks of the notes on one item: one per place, showing the number of open notes. A mark with only done
/// notes is grey. A click opens the notes of the item in a popover. The layer covers the item and takes no clicks
/// of its own.
struct NoteMarkers: View {
    let itemID: ItemID
    let size: CanvasSize
    let notes: [ItemNote]
    let store: BoardStore

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(NoteMarks.groups(notes)) { group in
                NoteMark(group: group, itemID: itemID, size: size, store: store)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// One mark: a capsule with the open count, centred on the place of its group.
private struct NoteMark: View {
    let group: NoteMarkGroup
    let itemID: ItemID
    let size: CanvasSize
    let store: BoardStore

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @State private var showing = false

    var body: some View {
        let point = NoteMarks.point(anchor: group.anchor, width: size.width, height: size.height)
        let done = group.open == 0
        Button {
            showing = true
        } label: {
            Text(verbatim: "\(group.open)")
                .themeText(theme.text(.caption))
                .monospacedDigit()
                .foregroundStyle(done ? theme.color(.textMuted, scheme) : theme.color(.text, scheme))
                .padding(.horizontal, theme.space(.s1))
                .frame(minWidth: theme.grid(3), minHeight: theme.grid(3))
                .background(Capsule().fill(done ? theme.color(.surface, scheme) : theme.color(.coral, scheme)))
        }
        .buttonStyle(.plain)
        .help(String(localized: "note.marker.help"))
        .popover(isPresented: $showing, arrowEdge: .bottom) {
            NotesListView(store: store, itemIDs: [itemID])
        }
        .position(x: point.x, y: point.y)
    }
}
