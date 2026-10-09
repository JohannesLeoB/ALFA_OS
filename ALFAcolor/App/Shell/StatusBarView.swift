import SwiftUI
import AppTheme
import BoardModel

/// Status bar at the bottom. Information only, no switches.
/// Only the save state shows a real value. The other values are placeholders.
struct StatusBarView: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    let saveState: SaveState
    /// The error of the last save. Shown as help text on the save state.
    let saveError: (any Error)?

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: theme.space(.s5)) {
                field("status.zoom", "status.zoom.value")
                field("status.grid", "status.grid.value")
                field("status.unit", "status.unit.value")
                field("status.selection", "status.selection.value")
                Spacer(minLength: 0)
                field("status.saveState", saveStateText)
                    .help(saveError?.localizedDescription ?? "")
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

    private var saveStateText: LocalizedStringKey {
        switch saveState {
        case .saved: "status.saveState.saved"
        case .modified: "status.saveState.modified"
        case .failed: "status.saveState.failed"
        }
    }

    private func field(_ name: LocalizedStringKey, _ value: LocalizedStringKey) -> some View {
        HStack(spacing: theme.space(.s1)) {
            Text(name)
            Text(value).foregroundStyle(theme.color(.text, scheme))
        }
        .accessibilityElement(children: .combine)
    }
}
