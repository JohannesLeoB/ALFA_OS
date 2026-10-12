import SwiftUI
import BoardModel

/// Room menu. Its entries come from `RoomMenu` in BoardModel. The only key is ⌘T, which adds a room.
struct RoomCommands: Commands {
    @FocusedValue(\.shell) private var shell
    @FocusedValue(\.canvas) private var canvas

    var body: some Commands {
        CommandMenu("menu.room") {
            RoomMenuItems(shell: shell, store: canvas?.store)
        }
    }
}

/// The entries of the room menu for the window in focus, also used by the tab row beyond six rooms.
/// Without a window, the entries stay dimmed.
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
                .keyboardShortcut("t", modifiers: .command)
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
        case .moveLeft(let enabled):
            Button("room.moveLeft") {
                if let id = store?.activeSpaceID { actions?.move(id, by: -1) }
            }
            .disabled(!enabled || actions == nil)
        case .moveRight(let enabled):
            Button("room.moveRight") {
                if let id = store?.activeSpaceID { actions?.move(id, by: 1) }
            }
            .disabled(!enabled || actions == nil)
        case .divider:
            Divider()
        case .room(let id, let name, let active):
            roomEntry(id: id, name: name, active: active, actions: actions)
        }
    }

    /// A room opens with a click. While other items are selected, the room also takes them.
    @ViewBuilder
    private func roomEntry(id: String, name: String, active: Bool, actions: RoomActions?) -> some View {
        let label = active ? Label(name, systemImage: "checkmark") : Label(name, systemImage: "rectangle.split.3x1")
        if let store, !active, !store.selection.isEmpty {
            Menu {
                Button("room.open") { actions?.select(id) }
                Button("room.moveSelection") { actions?.moveSelection(to: id) }
            } label: { label }
            .disabled(actions == nil)
        } else {
            Button { actions?.select(id) } label: { label }
                .disabled(actions == nil)
        }
    }

    private var actions: RoomActions? {
        guard let store, let shell else { return nil }
        return RoomActions(store: store, shell: shell)
    }
}
