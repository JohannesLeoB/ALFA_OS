import SwiftUI
import AppTheme

/// Status bar at the bottom. Information only, no switches. All values are placeholders.
struct StatusBarView: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: theme.space(.s5)) {
                field("status.zoom", "status.zoom.value")
                field("status.grid", "status.grid.value")
                field("status.unit", "status.unit.value")
                field("status.selection", "status.selection.value")
                Spacer(minLength: 0)
                field("status.saveState", "status.saveState.value")
            }
            .font(theme.text(.caption).font)
            .foregroundStyle(theme.color(.textMuted, scheme))
            .padding(.horizontal, theme.space(.s4))
            .padding(.vertical, theme.space(.s2))
        }
        .background(theme.color(.surface, scheme))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("status.title")
    }

    private func field(_ name: LocalizedStringKey, _ value: LocalizedStringKey) -> some View {
        HStack(spacing: theme.space(.s1)) {
            Text(name)
            Text(value).foregroundStyle(theme.color(.text, scheme))
        }
        .accessibilityElement(children: .combine)
    }
}
