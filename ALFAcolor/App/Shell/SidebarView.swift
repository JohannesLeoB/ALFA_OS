import SwiftUI
import AppTheme
import ALFAcolorCore
import BoardModel

/// Sidebar: the collection placeholders, the rooms from the seventh room on, the layers of the room
/// and the colour fields of the token set. The collection placeholders are dimmed and say they have no effect yet.
struct SidebarView: View {
    var store: BoardStore
    var shell: ShellState

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    private var layers: [Layer] { store.activeSpace?.layers ?? [] }

    var body: some View {
        List {
            LibrarySection(store: store)
            if store.board.spaces.count > SpaceTabBar.maxTabs {
                Section("sidebar.rooms") {
                    ForEach(store.board.spaces) { space in
                        roomRow(space)
                    }
                    .onMove(perform: moveRooms)
                }
            }
            Section("sidebar.layers") {
                if let spaceID = store.activeSpaceID {
                    ForEach(layers) { layer in
                        LayerRow(store: store, shell: shell, spaceID: spaceID, layer: layer)
                    }
                    .onMove(perform: moveLayers)
                }
                Button(action: addLayer) {
                    Label("layer.new", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .help("layer.new")
            }
            ItemList(store: store)
            ColorFieldsSection(store: store)
        }
        .font(theme.text(.body).font)
        .listStyle(.sidebar)
        .accessibilityLabel("sidebar.title")
    }

    /// One room of the list. A click opens it; its menu is the menu of the tab.
    private func roomRow(_ space: Space) -> some View {
        let active = space.id == store.activeSpaceID
        return Button { actions.select(space.id) } label: {
            Label {
                Text(space.name).lineLimit(1).truncationMode(.tail)
            } icon: {
                Image(systemName: "rectangle.split.3x1")
            }
        }
        .buttonStyle(.plain)
        .fontWeight(active ? .semibold : .regular)
        .contextMenu { RoomContextMenu(space: space, store: store, actions: actions) }
    }

    private var actions: RoomActions { RoomActions(store: store, shell: shell) }

    /// The list moves one room at a time, as the list moves one layer at a time.
    private func moveRooms(from offsets: IndexSet, to destination: Int) {
        guard let first = offsets.first, store.board.spaces.indices.contains(first) else { return }
        let position = first < destination ? destination - 1 : destination
        let id = store.board.spaces[first].id
        _ = try? store.changeBoard(nameKey: "undo.space.move") { try $0.moveSpace(id, to: position) }
    }

    /// Adds a layer on top of the room and marks it as the active one.
    private func addLayer() {
        guard let spaceID = store.activeSpaceID else { return }
        let id = store.board.freeLayerID(in: spaceID)
        let count = layers.count + 1
        let name = String(format: String(localized: "layer.numbered"), count)
        let added = try? store.changeBoard(nameKey: "undo.layer.add") {
            try $0.addLayer(id: id, name: name, in: spaceID)
        }
        if added == true { shell.activeLayer = id }
    }

    /// The list moves one layer at a time. The position counts the list before the layer is taken out.
    private func moveLayers(from offsets: IndexSet, to destination: Int) {
        guard let first = offsets.first, layers.indices.contains(first), let spaceID = store.activeSpaceID else { return }
        let position = first < destination ? destination - 1 : destination
        let layerID = layers[first].id
        _ = try? store.changeBoard(nameKey: "undo.layer.move") {
            try $0.moveLayer(layerID, to: position, in: spaceID)
        }
    }
}
