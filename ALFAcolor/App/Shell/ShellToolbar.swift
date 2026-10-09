import SwiftUI
import ALFAcolorCore
import BoardModel

/// Toolbar: room tabs on the left; add, import, lab and token workshop in the middle; export and inspector on the right.
/// Each button runs the function of a menu entry. The token workshop is not built yet, so it stays dimmed.
struct ShellToolbar: ToolbarContent {
    @Bindable var shell: ShellState
    var store: BoardStore

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            SpaceTabBar(shell: shell, store: store)
        }

        ToolbarItemGroup(placement: .principal) {
            AddMenu(store: store, shell: shell)
            ChooseFilesButton(titleKey: "toolbar.import", symbol: "square.and.arrow.down")
            LabButton()
            Button {} label: { Label("toolbar.tokenWorkshop", systemImage: "swatchpalette") }
                .help("toolbar.tokenWorkshop.later")
                .disabled(true)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            ExportButton(store: store)
            Button { shell.toggleInspector() } label: {
                Label("inspector.title", systemImage: "sidebar.trailing")
            }
            .help("toolbar.toggleInspector.help")
        }
    }
}

/// Opens the file chooser of the canvas. The files are placed as a paste is. Needs the canvas in focus.
private struct ChooseFilesButton: View {
    let titleKey: LocalizedStringKey
    let symbol: String

    @FocusedValue(\.interaction) private var interaction

    var body: some View {
        Button { interaction?.requestFileImport() } label: { Label(titleKey, systemImage: symbol) }
            .help(titleKey)
            .disabled(interaction == nil)
    }
}

/// The add menu: the file chooser, and a frame of each device. A new frame is centered on the visible part of the canvas.
private struct AddMenu: View {
    let store: BoardStore
    var shell: ShellState

    @FocusedValue(\.interaction) private var interaction
    @FocusedValue(\.canvas) private var canvas

    var body: some View {
        Menu {
            Button("toolbar.add.files") { interaction?.requestFileImport() }
            Menu("toolbar.add.frame") {
                ForEach(DeviceChoice.all) { choice in
                    Button(LocalizedStringKey(choice.nameKey)) { addFrame(choice.id) }
                }
            }
        } label: {
            Label("toolbar.add", systemImage: "plus.square.on.square")
        }
        .help("toolbar.add")
        .disabled(canvas == nil)
    }

    private func addFrame(_ deviceID: String) {
        guard let canvas else { return }
        let center = canvas.viewport.visibleRect(in: canvas.size).center
        _ = try? store.addFrame(deviceID: deviceID, centerX: center.x, centerY: center.y, layerID: shell.activeLayer)
    }
}

/// Opens the lab of the selected code card, or of a new empty card, as the L key does.
private struct LabButton: View {
    @FocusedValue(\.shell) private var shell
    @FocusedValue(\.canvas) private var canvas

    var body: some View {
        Button {
            guard let shell, let canvas else { return }
            shell.openLab(in: canvas)
        } label: {
            Label("toolbar.lab", systemImage: "testtube.2")
        }
        .help("toolbar.lab")
        .disabled(canvas == nil || shell == nil)
    }
}

/// Saves the mockup package through the save panel.
private struct ExportButton: View {
    let store: BoardStore

    var body: some View {
        Button { MockupExport.run(store: store) } label: {
            Label("toolbar.export", systemImage: "arrow.up.doc")
        }
        .help("toolbar.export")
    }
}
