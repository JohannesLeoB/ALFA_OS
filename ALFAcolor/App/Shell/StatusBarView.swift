import SwiftUI
import AppTheme
import BoardModel

/// Status bar at the bottom. Information only, no switches.
/// The save state, zoom, grid, unit, selection count and notice are real values, read from the same sources as the inspector.
struct StatusBarView: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    let saveState: SaveState
    /// The error of the last save. Shown as help text on the save state.
    let saveError: (any Error)?
    /// Zoom of the canvas in whole percent.
    let zoomPercent: Int
    /// Number of selected items. Zero shows the word for none.
    let selectionCount: Int
    /// The grid step in points. Zero means the grid is off.
    let gridStep: Double
    /// The unit that the inspector shows. Its symbol is read from the catalog.
    var unit: LengthUnit = .point
    /// A short notice: a catalog key, for example after a lab action, or a warning text from reading. nil shows nothing.
    var notice: String?

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: theme.space(.s5)) {
                field("status.zoom") { RollingText(text: "\(zoomPercent) %", style: .caption) }
                field("status.grid", gridText)
                field("status.unit", LocalizedStringKey(unit.symbolKey))
                field("status.selection") {
                    if selectionCount > 0 {
                        RollingText(text: "\(selectionCount)", style: .caption)
                    } else {
                        Text("status.selection.value")
                    }
                }
                if let notice {
                    Text(LocalizedStringKey(notice))
                        .foregroundStyle(theme.color(.coral, scheme))
                }
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

    /// The grid step in points, or "off". The inspector reads the same value.
    private var gridText: LocalizedStringKey {
        gridStep > 0 ? LocalizedStringKey(LengthUnit.point.text(points: gridStep)) : "inspector.room.gridOff"
    }

    private var saveStateText: LocalizedStringKey {
        switch saveState {
        case .saved: "status.saveState.saved"
        case .modified: "status.saveState.modified"
        case .new: "status.saveState.new"
        case .failed: "status.saveState.failed"
        }
    }

    private func field(_ name: LocalizedStringKey, _ value: LocalizedStringKey) -> some View {
        field(name) {
            Text(value)
        }
    }

    private func field<Value: View>(_ name: LocalizedStringKey, @ViewBuilder value: () -> Value) -> some View {
        HStack(spacing: theme.space(.s1)) {
            Text(name)
            value().foregroundStyle(theme.color(.text, scheme))
        }
        .accessibilityElement(children: .combine)
    }
}
