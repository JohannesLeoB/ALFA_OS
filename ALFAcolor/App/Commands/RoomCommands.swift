import SwiftUI
import BoardModel

/// Room menu. Its entries come from `RoomMenu` in BoardModel; none has a key, so the rooms are chosen with the mouse.
struct RoomCommands: Commands {
    @FocusedValue(\.shell) private var shell
    @FocusedValue(\.canvas) private var canvas

    var body: some Commands {
        CommandMenu("menu.room") {
            RoomMenuItems(shell: shell, store: canvas?.store)
        }
    }
}

/// The entries of the room menu for the window in focus. Without a window, the entries stay dimmed.
struct RoomMenuItems: View {
    let shell: ShellState?
    let store: BoardStore?

    var body: some View {
        let items = RoomMenu.items(spaces: store?.board.spaces ?? [], active: store?.activeSpaceID)
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
            entry(item)
        }
    }

    @ViewBuilder
    private func entry(_ item: RoomMenuItem) -> some View {
        let actions = actions
        switch item {
        case .add:
            Button("room.new") { actions?.add() }
                .disabled(actions == nil)
        case .rename(let enabled):
            Button("room.rename") {
                if let id = store?.activeSpaceID { actions?.startRename(id) }
            }
            .disabled(!enabled || actions == nil)
        case .close(let enabled):
            Button("room.close") {
                if let id = store?.activeSpaceID { actions?.requestClose(id) }
            }
            .disabled(!enabled || actions == nil)
        case .room(let id, let name, let active):
            Button { actions?.select(id) } label: {
                if active {
                    Label(name, systemImage: "checkmark")
                } else {
                    Text(name)
                }
            }
            .disabled(actions == nil)
        }
    }

    private var actions: RoomActions? {
        guard let store, let shell else { return nil }
        return RoomActions(store: store, shell: shell)
    }
}
