import SwiftUI
import AppTheme

/// Inspektor (B-102): Platzhalter für „keine Auswahl“. Echter Inhalt: B-208.
struct InspectorView: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.space(.s2)) {
            Text("Inspektor")
                .font(theme.text(.heading).font)
            Text("Keine Auswahl")
                .font(theme.text(.body).font)
            Text("Die Eigenschaften des Raums oder der Auswahl erscheinen hier.")
                .font(theme.text(.caption).font)
                .foregroundStyle(theme.color(.textMuted, scheme))
            Spacer(minLength: 0)
        }
        .padding(theme.space(.s4))
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Inspektor")
    }
}
