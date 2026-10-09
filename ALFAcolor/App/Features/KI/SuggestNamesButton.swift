import SwiftUI
import AppTheme
import AI
import BoardModel

/// The button under the colour fields: the assistant suggests names for the fields that still have the default name.
/// Each suggestion can be taken or left out in the sheet; nothing is renamed before that.
struct SuggestNamesButton: View {
    var store: BoardStore

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var openURL

    @State private var running = false
    @State private var notice: AssistantNotice?
    @State private var sheet: NameSheet?

    /// The suggestions of one answer, shown in the sheet.
    struct NameSheet: Identifiable {
        let id = UUID()
        let rows: [NameRow]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.space(.s1)) {
            Button("ki.names.suggest") { suggest() }
                .disabled(running)
            if let notice {
                Text(LocalizedStringKey(notice.textKey))
                    .themeText(theme.text(.caption))
                    .foregroundStyle(theme.color(.textMuted, scheme))
                if notice.action == .openConsole {
                    Button("ki.button.openConsole") {
                        if let url = AssistantStore.consoleURL { openURL(url) }
                    }
                }
            }
        }
        .sheet(item: $sheet) { item in
            NamesProposalSheet(store: store, rows: item.rows)
        }
    }

    private func suggest() {
        let fields = ColorFields.fields(in: store.document.tokenSets)
        let base = String(localized: "tokens.newName")
        let candidates = TokenNaming.candidates(from: fields.map { (name: $0.name, hex: $0.color.hex) }, base: base)
        guard !candidates.isEmpty else {
            notice = AssistantNotice(textKey: "ki.names.none", action: .none)
            return
        }
        running = true
        notice = nil
        Task {
            defer { running = false }
            do {
                let answer = try await AssistantStore.shared.run(.tokenNames(tokens: candidates, scheme: "color"))
                guard case let .names(names) = answer else {
                    throw AIError.unusableAnswer("the answer holds no names")
                }
                let rows = candidates.compactMap { candidate -> NameRow? in
                    guard let name = names[candidate.id] else { return nil }
                    return NameRow(old: candidate.id, suggested: name)
                }
                sheet = NameSheet(rows: rows)
            } catch let error as AIError {
                notice = AssistantMessages.notice(for: error)
            } catch {
                notice = AssistantMessages.notice(for: .network("names"))
            }
        }
    }
}

/// One suggested name: the field now, the name proposed, and whether it is taken.
struct NameRow: Identifiable {
    let old: String
    let suggested: String
    var isOn = true

    var id: String { old }
}

/// The sheet with the suggested names. "Annehmen" renames the ticked fields, one undo step each.
struct NamesProposalSheet: View {
    var store: BoardStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    @State private var rows: [NameRow]
    @State private var failed = false

    init(store: BoardStore, rows: [NameRow]) {
        self.store = store
        _rows = State(initialValue: rows)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.space(.s4)) {
            Text("ki.names.title")
                .themeText(theme.text(.heading))
            ForEach($rows) { $row in
                Toggle(isOn: $row.isOn) {
                    HStack(spacing: theme.space(.s2)) {
                        Text(verbatim: row.old)
                            .foregroundStyle(theme.color(.textMuted, scheme))
                        Text(verbatim: row.suggested)
                    }
                }
            }
            if failed {
                Text("tokens.notice.failed")
                    .foregroundStyle(theme.color(.textMuted, scheme))
            }
            HStack {
                Spacer()
                Button("ki.sheet.discard") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("ki.names.accept") { accept() }
                    .disabled(!rows.contains { $0.isOn })
            }
        }
        .padding(theme.space(.s6))
        .frame(minWidth: theme.grid(50))
    }

    private func accept() {
        for row in rows where row.isOn {
            do {
                _ = try store.renameColorField(row.old, to: row.suggested)
            } catch {
                failed = true
                return
            }
        }
        dismiss()
    }
}
