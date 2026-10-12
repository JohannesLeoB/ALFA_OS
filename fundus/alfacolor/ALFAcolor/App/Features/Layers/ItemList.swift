import SwiftUI
import AppTheme
import ALFAcolorCore
import BoardModel

/// The hidden items of the active room, each with an eye to show it again.
/// Hidden items leave the selection, so this list is the way back to them.
struct ItemList: View {
    var store: BoardStore

    @Environment(\.theme) private var theme

    var body: some View {
        let hidden = store.activeSpace?.items.filter(\.hidden) ?? []
        if !hidden.isEmpty {
            Section("items.hidden") {
                ForEach(hidden, id: \.id) { item in
                    HStack(spacing: theme.space(.s2)) {
                        Button { show(item) } label: {
                            Image(systemName: "eye.slash")
                        }
                        .buttonStyle(.borderless)
                        .help("items.show")
                        .accessibilityLabel("items.show")

                        Text(item.title)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private func show(_ item: Item) {
        _ = try? store.perform(.setHidden([item.id], false))
    }
}
