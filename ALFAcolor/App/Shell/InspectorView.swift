import SwiftUI
import AppTheme

/// Inspector: placeholder for "no selection".
struct InspectorView: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.space(.s2)) {
            Text("inspector.title")
                .font(theme.text(.heading).font)
            Text("inspector.noSelection")
                .font(theme.text(.body).font)
            Text("inspector.hint")
                .font(theme.text(.caption).font)
                .foregroundStyle(theme.color(.textMuted, scheme))
            Spacer(minLength: 0)
        }
        .padding(theme.space(.s4))
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("inspector.title")
    }
}
