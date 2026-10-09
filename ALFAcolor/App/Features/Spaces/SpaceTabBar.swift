import SwiftUI
import AppTheme
import ALFAcolorCore
import BoardModel

/// The room tabs of the toolbar. A double-click renames a room, dragging a tab moves it, and the menu of a tab
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
    }

    // MARK: Views

    private func tab(_ space: Space) -> some View {
        let active = space.id == store.activeSpaceID
        return Button { actions.select(space.id) } label: {
            Text(space.name)
                .font(theme.text(.body).font)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: maxTabWidth)
                .padding(.horizontal, theme.space(.s3))
                .padding(.vertical, theme.space(.s1))
                .background(active ? theme.color(.surface, scheme) : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .help(space.name)
        .accessibilityAddTraits(active ? .isSelected : [])
        .simultaneousGesture(TapGesture(count: 2).onEnded { actions.startRename(space.id) })
        .draggable(space.id)
        .dropDestination(for: String.self) { ids, _ in
            guard let moved = ids.first else { return false }
            return actions.reorder(moved, before: space.id)
        }
        .contextMenu { RoomContextMenu(space: space, store: store, actions: actions) }
    }

    /// The widest a tab label may grow: four of the largest space steps. A long name is cut at the end,
    /// so the tabs and the buttons after them keep their places.
    private var maxTabWidth: CGFloat { theme.space(.s8) * 4 }

    private var roomMenu: some View {
        Menu {
            RoomMenuItems(shell: shell, store: store)
        } label: {
            Text(store.activeSpace?.name ?? "")
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: maxTabWidth)
        }
        .help("room.sidebarHint")
    }
}

/// The rename and close dialogs. They hang on the window, not on the tab row, so they show with the tab row hidden.
struct RoomDialogs: ViewModifier {
    @Bindable var shell: ShellState
    var store: BoardStore

    func body(content: Self.Content) -> some View {
        let actions = RoomActions(store: store, shell: shell)
        content
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

    private var renamePresented: Binding<Bool> {
        Binding(get: { shell.renamingRoom != nil }, set: { if !$0 { shell.renamingRoom = nil } })
    }

    private var closePresented: Binding<Bool> {
        Binding(get: { shell.closingRoom != nil }, set: { if !$0 { shell.closingRoom = nil } })
    }
}
