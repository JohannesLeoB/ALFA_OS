import SwiftUI
import AppTheme

/// Seitenleiste (B-102) mit Platzhalter-Abschnitten aus plan/ANSICHTEN.md. Echter Inhalt: B-206, B-601.
struct SidebarView: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        List {
            Section("Sammlung") {
                Label("Alle Stücke", systemImage: "square.grid.2x2")
                Label("Bilder", systemImage: "photo")
                Label("Links", systemImage: "link")
            }
            Section("Ebenen") {
                Label("Ebene 1", systemImage: "square.3.layers.3d")
            }
            Section("Token-Satz") {
                Label("Noch keiner", systemImage: "swatchpalette")
                    .foregroundStyle(theme.color(.textMuted, scheme))
            }
        }
        .font(theme.text(.body).font)
        .listStyle(.sidebar)
        .accessibilityLabel("Seitenleiste")
    }
}
