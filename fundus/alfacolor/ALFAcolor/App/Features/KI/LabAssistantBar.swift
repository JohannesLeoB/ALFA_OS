import SwiftUI
import AppTheme
import AI
import CodePlayer

/// The assistant row under the lab's controls: an instruction with the variant button, the HTML button when the
/// draft has only styles, and a stop button while a call runs. A result opens as a proposal; nothing changes before that.
struct LabAssistantBar: View {
    let model: LabModel

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var openURL

    @State private var instruction = ""
    @State private var phase: Phase = .ready
    @State private var running: Task<Void, Never>?
    @State private var proposal: CodeProposal?

    /// The states of the row. A failure keeps its notice until the next call.
    enum Phase: Equatable {
        case ready
        case working
        case failed(AssistantNotice)
    }

    /// The HTML button shows only when the draft has styles and no markup, as the lab hint says.
    private var showsHTMLButton: Bool {
        LabHints.hints(for: model.session.draft).contains { $0.kind == .styleOnly }
    }

    private var canStartVariant: Bool {
        running == nil && !instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: theme.space(.s2)) {
            TextField("ki.lab.instruction", text: $instruction)
                .textFieldStyle(.roundedBorder)
                .onSubmit { if canStartVariant { startVariant() } }
            Button("ki.lab.variant") { startVariant() }
                .disabled(!canStartVariant)
            if showsHTMLButton {
                Button("ki.lab.htmlForCSS") { startHTML() }
                    .disabled(running != nil)
            }
            if running != nil {
                Button("ki.lab.stop") { running?.cancel() }
            }
            status
        }
        .themeText(theme.text(.caption))
        .padding(.horizontal, theme.space(.s3))
        .sheet(item: $proposal) { item in
            CodeProposalSheet(proposal: item) { files in keep(files) }
        }
    }

    @ViewBuilder
    private var status: some View {
        switch phase {
        case .ready:
            EmptyView()
        case .working:
            Text("ki.lab.working")
                .foregroundStyle(theme.color(.textMuted, scheme))
        case let .failed(notice):
            Text(LocalizedStringKey(notice.textKey))
                .foregroundStyle(theme.color(.textMuted, scheme))
            switch notice.action {
            case .none:
                EmptyView()
            case .openConsole:
                Button("ki.button.openConsole") { openConsole() }
            case .openSettings:
                SettingsLink { Text("ki.button.openSettings") }
            }
        }
    }

    // MARK: Actions

    private func startVariant() {
        let draft = model.session.draft
        let text = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        run(.codeVariant(language: draft.language.rawValue, files: draft.files, instruction: text), original: draft.files)
    }

    private func startHTML() {
        let draft = model.session.draft
        run(.htmlForCSS(css: draft.css), original: draft.files)
    }

    /// Runs one task in the background. The answer becomes a proposal over the files of the card.
    private func run(_ task: AITask, original: [String: String]) {
        phase = .working
        running = Task {
            do {
                let answer = try await AssistantStore.shared.run(task)
                guard case let .code(files, note) = answer else {
                    throw AIError.unusableAnswer("the answer holds no code")
                }
                proposal = CodeProposal(
                    original: original,
                    proposed: original.merging(files) { _, new in new },
                    note: note
                )
                phase = .ready
            } catch AIError.cancelled {
                phase = .ready
            } catch let error as AIError {
                phase = .failed(AssistantMessages.notice(for: error))
            } catch {
                phase = .failed(AssistantMessages.notice(for: .network("lab")))
            }
            running = nil
        }
    }

    /// Keeps the proposal as the card's new version. The lab draft takes the files, then the lab's own commit writes them.
    private func keep(_ files: [String: String]) {
        let draft = model.session.draft
        guard let next = LabDraft(card: CodeCard(language: draft.language, files: files), previewWidth: draft.width) else {
            return
        }
        for tab in next.tabs {
            model.edit(next.text(tab), in: tab)
        }
        model.commit()
    }

    private func openConsole() {
        if let url = AssistantStore.consoleURL {
            openURL(url)
        }
    }
}
