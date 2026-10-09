import SwiftUI
import AppTheme
import Renderers

/// The result of a code task: the files of the card before and after the proposal. Nothing is applied until the sheet says so.
struct CodeProposal: Identifiable, Equatable {
    let id = UUID()
    /// The files of the card as the lab holds them.
    let original: [String: String]
    /// The files after the proposal, with the files the proposal did not name kept as they were.
    let proposed: [String: String]
    /// The text that the answer carried next to the files.
    let note: String
}

/// The sheet with the original and the proposal side by side. The keep button stores the proposal as a new version.
struct CodeProposalSheet: View {
    let proposal: CodeProposal
    /// Called with the proposed files when the person keeps them.
    var onKeep: ([String: String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    private var names: [String] {
        Set(proposal.original.keys).union(proposal.proposed.keys).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.space(.s4)) {
            Text("ki.sheet.code.title")
                .themeText(theme.text(.heading))
            if !proposal.note.isEmpty {
                Text(verbatim: proposal.note)
                    .foregroundStyle(theme.color(.textMuted, scheme))
            }
            ScrollView {
                VStack(alignment: .leading, spacing: theme.space(.s4)) {
                    ForEach(names, id: \.self) { name in
                        file(name)
                    }
                }
            }
            HStack {
                Spacer()
                Button("ki.sheet.discard") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("ki.sheet.newVersion") {
                    onKeep(proposal.proposed)
                    dismiss()
                }
            }
        }
        .padding(theme.space(.s6))
        // Minimum size of the sheet: 680 by 480 points, in steps of the basic grid.
        .frame(minWidth: theme.grid(85), minHeight: theme.grid(60))
    }

    private func file(_ name: String) -> some View {
        let before = proposal.original[name] ?? ""
        let after = proposal.proposed[name] ?? ""
        return VStack(alignment: .leading, spacing: theme.space(.s2)) {
            Text(verbatim: name)
                .themeText(theme.text(.caption))
                .foregroundStyle(theme.color(.textMuted, scheme))
            HStack(alignment: .top, spacing: theme.space(.s4)) {
                column(title: "ki.sheet.original", text: before, changed: false)
                column(title: "ki.sheet.proposal", text: after, changed: before != after)
            }
        }
    }

    private func column(title: LocalizedStringKey, text: String, changed: Bool) -> some View {
        VStack(alignment: .leading, spacing: theme.space(.s1)) {
            Text(title)
                .themeText(theme.text(.caption))
                .foregroundStyle(theme.color(.textMuted, scheme))
            Text(verbatim: text.isEmpty ? " " : text)
                .themeText(theme.text(.code))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(theme.space(.s2))
                .background(theme.color(.surface, scheme))
                .signalRule(changed)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
