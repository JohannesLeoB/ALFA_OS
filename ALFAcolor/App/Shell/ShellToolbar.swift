import SwiftUI

/// Werkzeugleiste (B-102). Alle Knöpfe sind Platzhalter ohne Wirkung, bis ihre Briefe sie belegen.
/// Gruppen: links Raum-Reiter, Mitte Hinzufügen bis Token-Werkstatt, rechts Teilen, Ausgabe, Inspektor.
struct ShellToolbar: ToolbarContent {
    @Bindable var shell: ShellState

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Picker("Raum", selection: $shell.selectedRoom) {
                ForEach(PlaceholderRoom.allCases) { room in
                    Text(room.rawValue).tag(room)
                }
            }
            .pickerStyle(.segmented)
            .help("Raum wechseln")
            Button {} label: { Label("Neuer Raum", systemImage: "plus") }
                .help("Neuer Raum")
        }

        ToolbarItemGroup(placement: .principal) {
            Button {} label: { Label("Hinzufügen", systemImage: "plus.square.on.square") }
                .help("Hinzufügen")
            Button {} label: { Label("Importieren", systemImage: "square.and.arrow.down") }
                .help("Importieren")
            Button {} label: { Label("Labor", systemImage: "testtube.2") }
                .help("Labor")
            Button {} label: { Label("Token-Werkstatt", systemImage: "swatchpalette") }
                .help("Token-Werkstatt")
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button {} label: { Label("Teilen", systemImage: "square.and.arrow.up") }
                .help("Teilen")
            Button {} label: { Label("Ausgabe", systemImage: "arrow.up.doc") }
                .help("Ausgabe")
            Button { shell.toggleInspector() } label: {
                Label("Inspektor", systemImage: "sidebar.trailing")
            }
            .help("Inspektor ein- oder ausblenden (⌥⌘0)")
        }
    }
}
