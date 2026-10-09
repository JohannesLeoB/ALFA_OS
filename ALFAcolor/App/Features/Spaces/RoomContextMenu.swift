import SwiftUI
import ALFAcolorCore
import BoardModel

/// The menu of one room: rename, move, send the selection, close. It is the same in the tab row,
/// in the sidebar and wherever a room is listed, so no room needs more than the mouse.
struct RoomContextMenu: View {
    let space: Space
    let store: BoardStore
    let actions: RoomActions

    private var spaces: [Space] { store.board.spaces }
    private var position: Int? { spaces.firstIndex { $0.id == space.id } }
    private var isActive: Bool { space.id == store.activeSpaceID }

    var body: some View {
        Button("room.rename") { actions.startRename(space.id) }
        Button("room.moveLeft") { actions.move(space.id, by: -1) }
            .disabled(position == 0)
        Button("room.moveRight") { actions.move(space.id, by: 1) }
            .disabled(position == spaces.count - 1)
        Button("room.moveSelection") { actions.moveSelection(to: space.id) }
            .disabled(store.selection.isEmpty || isActive)
        Divider()
        Button("room.close") { actions.requestClose(space.id) }
            .disabled(spaces.count < 2)
    }
}
