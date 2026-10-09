import SwiftUI
import BoardModel

/// The button that opens the text styles sheet. The sidebar section of the token set shows it.
struct TextStylesButton: View {
    var store: BoardStore

    @State private var shown = false

    var body: some View {
        Button { shown = true } label: {
            Label("type.open", systemImage: "textformat")
        }
        .buttonStyle(.borderless)
        .help("type.open")
        .sheet(isPresented: $shown) {
            TextStylesSheet(store: store)
        }
    }
}
