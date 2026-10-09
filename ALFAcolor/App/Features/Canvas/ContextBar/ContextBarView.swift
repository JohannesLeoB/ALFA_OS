import SwiftUI
import ALFAcolorCore
import AppTheme
import BoardModel

/// The context bar: a pill of glass that floats over the selection. The count is in mono on the left,
/// the entries are text. Each entry is one command, so each one is one undo step.
struct ContextBarView: View {
    var store: BoardStore

    @Environment(\.theme) private var theme

    /// The entries in groups; a divider comes before each group that is shown after the first.
    private static let groups: [[ContextAction]] = [
        [.alignLeft, .alignTop, .alignCenter],
        [.row, .grid, .pile, .sameSize],
        [.group, .ungroup],
        [.toFront, .forward, .backward],
        [.lock],
    ]

    var body: some View {
        let items = store.selectedItems
        let actions = ContextBar.actions(count: items.count, hasGroup: ContextBar.hasGroup(items))
        let allLocked = !items.isEmpty && items.allSatisfy(\.locked)
        HStack(spacing: theme.space(.s2)) {
            caption(for: items)
            ForEach(Array(Self.groups.enumerated()), id: \.offset) { index, group in
                let shown = group.filter { actions.contains($0) }
                if !shown.isEmpty {
                    if index > 0 { Divider().frame(height: theme.space(.s4)) }
                    ForEach(shown, id: \.self) { action in
                        entry(action, allLocked: allLocked)
                    }
                }
            }
        }
        .font(theme.text(.caption).font)
        .padding(.horizontal, theme.space(.s3))
        .padding(.vertical, theme.space(.s1))
        // One row high: the bar takes its ideal size, never the height that the placement offers it.
        .fixedSize()
        .glassEffect(.regular, in: .capsule)
    }

    /// The count of several items, or the kind of a single item.
    @ViewBuilder
    private func caption(for items: [Item]) -> some View {
        if items.count >= 2 {
            Text("context.count \(items.count)")
                .font(theme.text(.caption).font.monospacedDigit())
        } else if let kind = Inspection(items: items).kind.value {
            Text(LocalizedStringKey(kind.nameKey))
        }
    }

    private func entry(_ action: ContextAction, allLocked: Bool) -> some View {
        Button {
            _ = try? store.perform(action, groupTitle: String(localized: "item.kind.group"))
        } label: {
            Text(LocalizedStringKey(action.labelKey(allLocked: allLocked)))
        }
        .buttonStyle(.plain)
        .help(LocalizedStringKey(action.helpKey(allLocked: allLocked)))
    }
}
