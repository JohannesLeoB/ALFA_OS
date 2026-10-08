import SwiftUI
import AppTheme

/// Sidebar with placeholder sections from plan/ANSICHTEN.md.
struct SidebarView: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        List {
            Section("sidebar.collection") {
                Label("sidebar.allItems", systemImage: "square.grid.2x2")
                Label("sidebar.images", systemImage: "photo")
                Label("sidebar.links", systemImage: "link")
            }
            Section("sidebar.layers") {
                Label("sidebar.layer1", systemImage: "square.3.layers.3d")
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
}
