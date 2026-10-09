import SwiftUI
import AppTheme
import ALFAcolorCore
import BoardModel

/// The room tabs of the toolbar. A double-click renames a room, dragging a tab moves it, the menu of a tab
/// moves, closes and sends the selection to it. From the seventh room on, a menu replaces the tabs
/// and the sidebar lists the rooms. The room menu offers the same actions with the mouse, and no keys.
struct SpaceTabBar: View {
    /// The most rooms that the tab row shows.
    static let maxTabs = 6

    @Bindable var shell: ShellState
    var store: BoardStore

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    private var spaces: [Space] { store.board.spaces }
    private var actions: RoomActions { RoomActions(store: store, shell: shell) }

    var body: some View {
        HStack(spacing: theme.space(.s1)) {
            if spaces.count <= Self.maxTabs {
                ForEach(spaces) { space in tab(space) }
            } else {
                roomMenu
            }
            Button { actions.add() } label: { Label("room.new", systemImage: "plus") }
                .help("room.new")
        }
        .background { shortcut }
        .alert("room.rename.title", isPresented: renamePresented) {
            TextField("room.name", text: $shell.roomDraft)
            Button("room.rename.confirm") { actions.commitRename() }
            Button("room.cancel", role: .cancel) {}
        }
        .confirmationDialog("room.close.title", isPresented: closePresented, titleVisibility: .visible) {
            Button("room.close.action", role: .destructive) {
                if let id = shell.closingRoom { actions.close(id) }
            }
        } message: {
            Text("room.close.message")
        }
    }

    // MARK: Views

    private func tab(_ space: Space) -> some View {
        let active = space.id == store.activeSpaceID
        return Button { actions.select(space.id) } label: {
            Text(space.name)
                .font(theme.text(.body).font)
                .padding(.horizontal, theme.space(.s3))
                .padding(.vertical, theme.space(.s1))
                .background(active ? theme.color(.surface, scheme) : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
        .simultaneousGesture(TapGesture(count: 2).onEnded { actions.startRename(space.id) })
        .draggable(space.id)
        .dropDestination(for: String.self) { ids, _ in
            guard let moved = ids.first else { return false }
            return reorder(moved, before: space.id)
        }
        .contextMenu {
            Button("room.rename") { actions.startRename(space.id) }
            Button("room.moveLeft") { move(space.id, by: -1) }
                .disabled(index(of: space.id) == 0)
            Button("room.moveRight") { move(space.id, by: 1) }
                .disabled(index(of: space.id) == spaces.count - 1)
            Button("room.moveSelection") { moveSelection(to: space.id) }
                .disabled(store.selection.isEmpty || active)
            Divider()
            Button("room.close") { actions.requestClose(space.id) }
                .disabled(spaces.count < 2)
        }
    }

    private var roomMenu: some View {
        Menu {
            ForEach(spaces) { space in
                Button(space.name) { actions.select(space.id) }
            }
        } label: {
            Text(store.activeSpace?.name ?? "")
        }
        .help("room.sidebarHint")
    }

    /// The key without a visible button: ⌘T adds a room. The rooms are otherwise chosen with the mouse.
    private var shortcut: some View {
        Button("") { actions.add() }
            .keyboardShortcut("t", modifiers: .command)
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
    }

    // MARK: Sheets

    private var renamePresented: Binding<Bool> {
        Binding(get: { shell.renamingRoom != nil }, set: { if !$0 { shell.renamingRoom = nil } })
    }

    private var closePresented: Binding<Bool> {
        Binding(get: { shell.closingRoom != nil }, set: { if !$0 { shell.closingRoom = nil } })
    }

    // MARK: Actions. Each change is one undo step.

    private func index(of id: String) -> Int? {
        spaces.firstIndex { $0.id == id }
    }

    private func move(_ id: String, by step: Int) {
        guard let at = index(of: id) else { return }
        let position = at + step
        _ = try? store.changeBoard(nameKey: "undo.space.move") { try $0.moveSpace(id, to: position) }
    }

    /// A tab dropped on another tab takes its place in front of it.
    private func reorder(_ id: String, before target: String) -> Bool {
        guard id != target, let from = index(of: id), let to = index(of: target) else { return false }
        let position = from < to ? to - 1 : to
        return (try? store.changeBoard(nameKey: "undo.space.move") { try $0.moveSpace(id, to: position) }) == true
    }

    private func moveSelection(to id: String) {
        guard let from = store.activeSpaceID else { return }
        let items = store.selection
        _ = try? store.changeBoard(nameKey: "undo.space.moveItems") { try $0.moveItems(items, from: from, to: id) }
    }
}
