import SwiftUI
import AppTheme

/// Statusleiste unten (B-102). Nur Angaben, keine Schalter. Alle Werte sind Platzhalter, bis B-203 und B-201 sie liefern.
struct StatusBarView: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: theme.space(.s5)) {
                field("Zoom", "100 %")
                field("Raster", "8")
                field("Einheit", "pt")
                field("Auswahl", "keine")
                Spacer(minLength: 0)
                field("Speicherstand", "Gesichert")
            }
            .font(theme.text(.beschriftung).font)
            .foregroundStyle(theme.color(.textLeise, scheme))
            .padding(.horizontal, theme.space(.s4))
            .padding(.vertical, theme.space(.s2))
        }
        .background(theme.color(.flaeche, scheme))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Statusleiste")
    }

    private func field(_ name: String, _ value: String) -> some View {
        HStack(spacing: theme.space(.s1)) {
            Text(name)
            Text(value).foregroundStyle(theme.color(.text, scheme))
        }
        .accessibilityElement(children: .combine)
    }
}
