import SwiftUI
import AppTheme
import ALFAcolorCore
import BoardModel

/// Sidebar: the collection placeholders, the rooms from the seventh room on, the layers of the room
/// and the token set placeholder (plan/ANSICHTEN.md).
struct SidebarView: View {
    var store: BoardStore

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    private var layers: [Layer] { store.activeSpace?.layers ?? [] }

    var body: some View {
        List {
            Section("sidebar.collection") {
                Label("sidebar.allItems", systemImage: "square.grid.2x2")
                Label("sidebar.images", systemImage: "photo")
                Label("sidebar.links", systemImage: "link")
            }
            if store.board.spaces.count > SpaceTabBar.maxTabs {
                Section("sidebar.rooms") {
                    ForEach(store.board.spaces) { space in
                        Button { _ = try? store.perform(.switchSpace(space.id)) } label: {
                            Label(space.name, systemImage: "rectangle.split.3x1")
                        }
                        .buttonStyle(.plain)
                        .fontWeight(space.id == store.activeSpaceID ? .semibold : .regular)
                    }
                }
            }
            Section("sidebar.layers") {
                if let spaceID = store.activeSpaceID {
                    ForEach(layers) { layer in
                        LayerRow(store: store, spaceID: spaceID, layer: layer)
                    }
                    .onMove(perform: moveLayers)
                }
            }
            Section("sidebar.tokenSet") {
                Label("sidebar.noTokenSet", systemImage: "swatchpalette")
                    .foregroundStyle(theme.color(.textMuted, scheme))
            }
        }
        .font(theme.text(.body).font)
        .listStyle(.sidebar)
        .accessibilityLabel("sidebar.title")
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
