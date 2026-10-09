import SwiftUI
import AppTheme
import ALFAcolorCore
import BoardModel

/// The room tabs of the toolbar. A double-click renames a room, dragging a tab moves it, the menu of a tab
/// moves, closes and sends the selection to it. From the seventh room on, a menu replaces the tabs
/// and the sidebar lists the rooms.
struct SpaceTabBar: View {
    /// The most rooms that the tab row shows.
    static let maxTabs = 6

    var store: BoardStore

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @State private var renamingID: String?
    @State private var draftName = ""
    @State private var closingID: String?

    private var spaces: [Space] { store.board.spaces }

    var body: some View {
        HStack(spacing: theme.space(.s1)) {
            if spaces.count <= Self.maxTabs {
                ForEach(spaces) { space in tab(space) }
            } else {
                roomMenu
            }
            Button(action: addRoom) { Label("room.new", systemImage: "plus") }
                .help("room.new")
        }
        .background { shortcuts }
        .alert("room.rename.title", isPresented: renamePresented) {
            TextField("room.name", text: $draftName)
            Button("room.rename.confirm", action: commitRename)
            Button("room.cancel", role: .cancel) {}
        }
        .confirmationDialog("room.close.title", isPresented: closePresented, titleVisibility: .visible) {
            Button("room.close.action", role: .destructive) {
                if let id = closingID { close(id) }
            }
        } message: {
            Text("room.close.message")
        }
    }

    // MARK: Views

    private func tab(_ space: Space) -> some View {
        let active = space.id == store.activeSpaceID
        return Button { select(space.id) } label: {
            Text(space.name)
                .font(theme.text(.body).font)
                .padding(.horizontal, theme.space(.s3))
                .padding(.vertical, theme.space(.s1))
                .background(active ? theme.color(.surface, scheme) : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
        .simultaneousGesture(TapGesture(count: 2).onEnded { startRename(space) })
        .draggable(space.id)
        .dropDestination(for: String.self) { ids, _ in
            guard let moved = ids.first else { return false }
            return reorder(moved, before: space.id)
        }
        .contextMenu {
            Button("room.rename") { startRename(space) }
            Button("room.moveLeft") { move(space.id, by: -1) }
                .disabled(index(of: space.id) == 0)
            Button("room.moveRight") { move(space.id, by: 1) }
                .disabled(index(of: space.id) == spaces.count - 1)
            Button("room.moveSelection") { moveSelection(to: space.id) }
                .disabled(store.selection.isEmpty || active)
            Divider()
            Button("room.close") { requestClose(space) }
                .disabled(spaces.count < 2)
        }
    }

    private var roomMenu: some View {
        Menu {
            ForEach(spaces) { space in
                Button(space.name) { select(space.id) }
            }
        } label: {
            Text(store.activeSpace?.name ?? "")
        }
        .help("room.sidebarHint")
    }

    /// The keys without a visible button: ⌘T adds a room, ⌃1 to ⌃9 select the first nine rooms.
    private var shortcuts: some View {
        ZStack {
            Button("", action: addRoom)
                .keyboardShortcut("t", modifiers: .command)
            ForEach(1...9, id: \.self) { number in
                Button("") { jump(to: number - 1) }
                    .keyboardShortcut(KeyEquivalent(Character(String(number))), modifiers: .control)
            }
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    // MARK: Sheets

    private var renamePresented: Binding<Bool> {
        Binding(get: { renamingID != nil }, set: { if !$0 { renamingID = nil } })
    }

    private var closePresented: Binding<Bool> {
        Binding(get: { closingID != nil }, set: { if !$0 { closingID = nil } })
    }

    // MARK: Actions. Each change is one undo step.

    private func index(of id: String) -> Int? {
        spaces.firstIndex { $0.id == id }
    }

    private func select(_ id: String) {
        _ = try? store.perform(.switchSpace(id))
    }

    private func jump(to position: Int) {
        guard spaces.indices.contains(position) else { return }
        select(spaces[position].id)
    }

    private func addRoom() {
        let id = store.board.freeSpaceID()
        let added = try? store.changeBoard(nameKey: "undo.space.add") {
            try $0.addSpace(id: id, name: String(localized: "room.defaultName"))
        }
        if added == true { select(id) }
    }

    private func startRename(_ space: Space) {
        draftName = space.name
        renamingID = space.id
    }

    private func commitRename() {
        guard let id = renamingID else { return }
        renamingID = nil
        let name = draftName
        _ = try? store.changeBoard(nameKey: "undo.space.rename") { try $0.renameSpace(id, to: name) }
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

    private func requestClose(_ space: Space) {
        if store.board.spaceHasContent(space.id) {
            closingID = space.id
        } else {
            close(space.id)
        }
    }

    /// Removes a room. The room next to it becomes the active one when the closed room was active.
    private func close(_ id: String) {
        closingID = nil
        let order = spaces.map(\.id)
        guard order.count > 1, let at = order.firstIndex(of: id) else { return }
        let next = at + 1 < order.count ? order[at + 1] : order[at - 1]
        let wasActive = id == store.activeSpaceID
        guard (try? store.changeBoard(nameKey: "undo.space.remove") { try $0.removeSpace(id) }) == true else { return }
        if wasActive { select(next) }
    }

    private func moveSelection(to id: String) {
        guard let from = store.activeSpaceID else { return }
        let items = store.selection
        _ = try? store.changeBoard(nameKey: "undo.space.moveItems") { try $0.moveItems(items, from: from, to: id) }
    }
}
