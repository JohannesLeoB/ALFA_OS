import SwiftUI
import ALFAcolorCore
import BoardModel

/// The room actions of the tab row and the room menu. Each change is one undo step.
/// Renaming and closing ask through `ShellState`, so the dialogs show in the window whichever control starts them.
@MainActor
struct RoomActions {
    let store: BoardStore
    let shell: ShellState

    private var spaces: [Space] { store.board.spaces }

    func select(_ id: String) {
        _ = try? store.perform(.switchSpace(id))
    }

    func add() {
        let id = store.board.freeSpaceID()
        let added = try? store.changeBoard(nameKey: "undo.space.add") {
            try $0.addSpace(id: id, name: String(localized: "room.defaultName"))
        }
        if added == true { select(id) }
    }

    func startRename(_ id: String) {
        guard let space = spaces.first(where: { $0.id == id }) else { return }
        shell.roomDraft = space.name
        shell.renamingRoom = id
    }

    func commitRename() {
        guard let id = shell.renamingRoom else { return }
        shell.renamingRoom = nil
        let name = shell.roomDraft
        _ = try? store.changeBoard(nameKey: "undo.space.rename") { try $0.renameSpace(id, to: name) }
    }

    /// Closes at once when the room is empty; otherwise the confirmation asks first.
    func requestClose(_ id: String) {
        if store.board.spaceHasContent(id) {
            shell.closingRoom = id
        } else {
            close(id)
        }
    }

    /// Removes a room. The room next to it becomes the active one when the closed room was active.
    func close(_ id: String) {
        shell.closingRoom = nil
        let order = spaces.map(\.id)
        guard order.count > 1, let at = order.firstIndex(of: id) else { return }
        let next = at + 1 < order.count ? order[at + 1] : order[at - 1]
        let wasActive = id == store.activeSpaceID
        guard (try? store.changeBoard(nameKey: "undo.space.remove") { try $0.removeSpace(id) }) == true else { return }
        if wasActive { select(next) }
    }
}
