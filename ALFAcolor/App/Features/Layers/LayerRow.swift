import SwiftUI
import AppTheme
import ALFAcolorCore
import BoardModel

/// One layer in the sidebar: show or hide, lock, name and the number of items.
/// The menu puts the selection on the layer. Reordering is done by the list.
struct LayerRow: View {
    var store: BoardStore
    var spaceID: String
    var layer: Layer

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: theme.space(.s2)) {
            Button(action: toggleVisible) {
                Image(systemName: layer.visible ? "eye" : "eye.slash")
            }
            .buttonStyle(.borderless)
            .help(layer.visible ? "layer.hide" : "layer.show")
            .accessibilityLabel(layer.visible ? "layer.hide" : "layer.show")

            Button(action: toggleLock) {
                Image(systemName: layer.locked ? "lock" : "lock.open")
            }
            .buttonStyle(.borderless)
            .help(layer.locked ? "layer.unlock" : "layer.lock")
            .accessibilityLabel(layer.locked ? "layer.unlock" : "layer.lock")

            Text(layer.name)
                .lineLimit(1)
            Spacer()
            Text("\(count)")
                .monospacedDigit()
                .foregroundStyle(theme.color(.textMuted, scheme))
        }
        .contextMenu {
            Button("layer.moveSelection", action: putSelection)
                .disabled(store.selection.isEmpty)
        }
    }

    private var count: Int {
        store.board.itemCount(layer: layer.id, in: spaceID)
    }

    private func toggleVisible() {
        let visible = !layer.visible
        _ = try? store.changeBoard(nameKey: "undo.layer.visible") {
            try $0.setLayerVisible(visible, layer: layer.id, in: spaceID)
        }
    }

    private func toggleLock() {
        let locked = !layer.locked
        _ = try? store.changeBoard(nameKey: "undo.layer.locked") {
            try $0.setLayerLocked(locked, layer: layer.id, in: spaceID)
        }
    }

    private func putSelection() {
        _ = try? store.perform(.moveToLayer(store.selection, layerID: layer.id))
    }
}
