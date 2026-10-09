import SwiftUI
import BoardModel

/// The button in the token-set section that opens the output sheet.
struct WorkshopExportButton: View {
    var store: BoardStore

    @State private var shown = false

    var body: some View {
        Button { shown = true } label: {
            Label("command.file.export", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(.borderless)
        .help("command.file.export")
        .sheet(isPresented: $shown) {
            ExportSheet(store: store)
        }
    }
}
