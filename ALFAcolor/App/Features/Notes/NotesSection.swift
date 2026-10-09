import SwiftUI
import ALFAcolorCore
import BoardModel

/// The notes section of the inspector, for the selected items. It is not shown without a selection.
struct NotesSection: View {
    var store: BoardStore
    var items: [Item]

    var body: some View {
        Section("inspector.notes") {
            NotesListView(store: store, itemIDs: items.map(\.id))
        }
    }
}
