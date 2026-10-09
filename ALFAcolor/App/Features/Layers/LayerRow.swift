import SwiftUI
import AppTheme
import ALFAcolorCore
import BoardModel

/// One layer in the sidebar: show or hide, lock, name and the number of items. A click makes it the active layer;
/// a double-click renames it. The menu puts the selection on the layer, renames, and deletes it.
/// Reordering is done by the list.
struct LayerRow: View {
    var store: BoardStore
    var shell: ShellState
    var spaceID: String
    var layer: Layer

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @State private var draft = ""
    @State private var editing = false
    @FocusState private var focused: Bool

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

            if editing {
                TextField("layer.name", text: $draft)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onSubmit(commitRename)
                    .onExitCommand { editing = false }
            } else {
                Text(layer.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2, perform: startRename)
                    .onTapGesture(perform: makeActive)
            }
            Spacer()
            Text("\(count)")
                .monospacedDigit()
                .foregroundStyle(theme.color(.textMuted, scheme))
        }
        .listRowBackground(isActive ? theme.color(.surface, scheme) : Color.clear)
        .onChange(of: focused) { _, isFocused in
            if !isFocused && editing { commitRename() }
        }
        .contextMenu {
            Button("layer.moveSelection", action: putSelection)
                .disabled(store.selection.isEmpty)
            Button("layer.rename", action: startRename)
            Button("layer.delete", action: remove)
                .disabled(store.activeSpace?.layers.count ?? 0 < 2)
        }
    }

    private var isActive: Bool { shell.activeLayer == layer.id }

    private var count: Int {
        store.board.itemCount(layer: layer.id, in: spaceID)
    }

    private func makeActive() {
        shell.activeLayer = layer.id
    }

    private func startRename() {
        draft = layer.name
        editing = true
        focused = true
    }

    /// An empty name keeps the old name. Each rename is one undo step.
    private func commitRename() {
        let name = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        editing = false
        guard !name.isEmpty, name != layer.name else { return }
        _ = try? store.changeBoard(nameKey: "undo.layer.rename") {
            try $0.renameLayer(layer.id, to: name, in: spaceID)
        }
    }

    private func remove() {
        _ = try? store.changeBoard(nameKey: "undo.layer.remove") {
            try $0.removeLayer(layer.id, in: spaceID)
        }
        if isActive { shell.activeLayer = nil }
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
