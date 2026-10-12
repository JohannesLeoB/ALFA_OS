import SwiftUI
import ALFAcolorCore
import BoardModel

/// The room actions of the tab row, the room menu and the sidebar. Each change is one undo step.
/// Renaming and closing ask through `ShellState`, so the dialogs show in the window whichever control starts them
/// (`RoomDialogs`, attached to the window).
@MainActor
struct RoomActions {
    let store: BoardStore
    let shell: ShellState

    private var spaces: [Space] { store.board.spaces }

    func select(_ id: String) {
        _ = try? store.perform(.switchSpace(id))
    }

    /// Adds a room at the end, named "Raum 2", "Raum 3" and so on, and opens it.
    func add() {
        let id = store.board.freeSpaceID()
        let name = store.board.freeSpaceName(template: String(localized: "room.numbered"))
        let added = try? store.changeBoard(nameKey: "undo.space.add") {
            try $0.addSpace(id: id, name: name)
        }
        if added == true { select(id) }
    }

    func startRename(_ id: String) {
        guard let space = spaces.first(where: { $0.id == id }) else { return }
        shell.roomDraft = space.name
        shell.renamingRoom = id
    }

    /// Renames the room. An empty name keeps the old name and says so in the status bar.
    func commitRename() {
        guard let id = shell.renamingRoom else { return }
        shell.renamingRoom = nil
        let name = shell.roomDraft
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            shell.roomNotice = "room.rename.empty"
            return
        }
        shell.roomNotice = nil
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

    /// Moves a room by `step` places in the tab order. Nothing happens past either end.
    func move(_ id: String, by step: Int) {
        guard let at = spaces.firstIndex(where: { $0.id == id }) else { return }
        _ = try? store.changeBoard(nameKey: "undo.space.move") { try $0.moveSpace(id, to: at + step) }
    }

    /// Moves a room in front of another room, as a drop on a tab does.
    func reorder(_ id: String, before target: String) -> Bool {
        guard id != target, let from = spaces.firstIndex(where: { $0.id == id }),
              let to = spaces.firstIndex(where: { $0.id == target }) else { return false }
        let position = from < to ? to - 1 : to
        return (try? store.changeBoard(nameKey: "undo.space.move") { try $0.moveSpace(id, to: position) }) == true
    }

    /// Moves the selection to another room. The items keep their place inside the room.
    func moveSelection(to id: String) {
        guard let from = store.activeSpaceID, id != from else { return }
        let items = store.selection
        _ = try? store.changeBoard(nameKey: "undo.space.moveItems") { try $0.moveItems(items, from: from, to: id) }
    }
}
