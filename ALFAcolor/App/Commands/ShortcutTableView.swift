import SwiftUI
import AppTheme
import ALFAcolorCore

/// Shortcut table: all commands with shortcuts, ordered by menu. Reads the table from ALFAcolorCore.
/// Opens through Help > Shortcut Table. Values come from the theme, no fixed colors.
struct ShortcutTableView: View {
    static let windowID = "shortcutTable"

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.space(.s5)) {
                ForEach(AppMenu.allCases, id: \.self) { menu in
                    VStack(alignment: .leading, spacing: theme.space(.s2)) {
                        Text(LocalizedStringKey(menu.titleKey))
                            .font(theme.text(.heading).font)
                            .foregroundStyle(theme.color(.text, scheme))
                        ForEach(ShortcutTable.commands.filter { $0.menu == menu }) { command in
                            row(command)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: theme.space(.s2)) {
                    Text("menu.canvasKeys")
                        .font(theme.text(.heading).font)
                        .foregroundStyle(theme.color(.text, scheme))
                    ForEach(Self.canvasKeys, id: \.self) { key in
                        Text(LocalizedStringKey(key))
                            .font(theme.text(.body).font)
                            .foregroundStyle(theme.color(.text, scheme))
                    }
                }
            }
            .padding(theme.space(.s5))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.color(.background, scheme))
        .frame(minWidth: 420, minHeight: 480)
    }

    /// Keys that work on the canvas without a menu entry.
    private static let canvasKeys = [
        "shortcuts.key.arrows", "shortcuts.key.space", "shortcuts.key.tab", "shortcuts.key.escape", "shortcuts.key.delete",
    ]

    private func row(_ command: MenuCommand) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: theme.space(.s3)) {
            Text(LocalizedStringKey(command.titleKey))
                .foregroundStyle(theme.color(.text, scheme))
            if command.scope == .canvasOnly {
                Text("shortcuts.canvasOnly")
                    .foregroundStyle(theme.color(.textMuted, scheme))
            }
            if ShortcutTable.withoutEffect.contains(command.id) {
                Text("shortcuts.noEffect")
                    .foregroundStyle(theme.color(.textMuted, scheme))
            }
            Spacer(minLength: theme.space(.s2))
            Text(command.shortcut?.display ?? "")
                .foregroundStyle(theme.color(.textMuted, scheme))
        }
        .font(theme.text(.body).font)
        .accessibilityElement(children: .combine)
    }
}
