import SwiftUI
import ALFAcolorCore
import BoardModel

/// The inspector: the fields of the selection, or of the room when nothing is selected.
/// The values come from `Inspection`; each change is one command on the store, so it is one undo step.
struct InspectorPanel: View {
    var store: BoardStore
    var snap: SnapSettings
    var interaction: CanvasInteraction
    /// Unit of the position fields. It lives in the window state, so it stays when the inspector is hidden.
    @Binding var unit: LengthUnit

    var body: some View {
        let items = store.selectedItems
        Form {
            // The options of the active tool come first; the selection tool shows none.
            ToolOptionsSection(interaction: interaction, unit: $unit)
            if items.isEmpty {
                RoomSection(store: store, snap: snap, interaction: interaction)
            } else {
                HeaderSection(items: items)
                PositionSection(store: store, items: items, unit: $unit)
                LayerSection(store: store, items: items)
                if let kind = Inspection(items: items).kind.value,
                   let section = KindInspectors.section(for: kind, store: store, items: items) {
                    section
                }
            }
        }
        .formStyle(.grouped)
    }
}
