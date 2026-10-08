import SwiftUI

/// Toolbar. All buttons are placeholders without effect.
/// Groups: space tabs on the left, add to token workshop in the middle, share, export and inspector on the right.
struct ShellToolbar: ToolbarContent {
    @Bindable var shell: ShellState

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Picker("toolbar.space", selection: $shell.selectedRoom) {
                ForEach(PlaceholderRoom.allCases) { room in
                    Text(LocalizedStringKey(room.rawValue)).tag(room)
                }
            }
            .pickerStyle(.segmented)
            .help("toolbar.switchSpace.help")
            Button {} label: { Label("toolbar.newSpace", systemImage: "plus") }
                .help("toolbar.newSpace")
        }

        ToolbarItemGroup(placement: .principal) {
            Button {} label: { Label("toolbar.add", systemImage: "plus.square.on.square") }
                .help("toolbar.add")
            Button {} label: { Label("toolbar.import", systemImage: "square.and.arrow.down") }
                .help("toolbar.import")
            Button {} label: { Label("toolbar.lab", systemImage: "testtube.2") }
                .help("toolbar.lab")
            Button {} label: { Label("toolbar.tokenWorkshop", systemImage: "swatchpalette") }
                .help("toolbar.tokenWorkshop")
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button {} label: { Label("toolbar.share", systemImage: "square.and.arrow.up") }
                .help("toolbar.share")
            Button {} label: { Label("toolbar.export", systemImage: "arrow.up.doc") }
                .help("toolbar.export")
            Button { shell.toggleInspector() } label: {
                Label("inspector.title", systemImage: "sidebar.trailing")
            }
            .help("toolbar.toggleInspector.help")
        }
    }
}
