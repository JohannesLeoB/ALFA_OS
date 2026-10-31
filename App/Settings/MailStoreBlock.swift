import AppKit
import Design
import Hub
import Mail
import SwiftUI

struct MailStoreBlock: View {
    @Environment(\.appearance) private var appearance
    let context: SettingsContext
    let inlets: [Inlet]
    @State private var folderName: String?

    private var state: SettingsState { context.state }

    var body: some View {
        let mirrored = inlets.filter { !context.inbox.ranges($0.id).isEmpty }
        if !mirrored.isEmpty {
            BlockHead(key: "settings.mailStore.head")
            ForEach(mirrored) { inlet in
                MailboxRangeRow(state: state, inbox: context.inbox, inlet: inlet, named: mirrored.count > 1)
            }
            attachments
            limit
            folder
                .task(id: state.mailStore.folder) {
                    folderName = state.mailStore.folder.flatMap(AttachmentFolder.url(for:)).map {
                        ($0.appendingPathComponent(AttachmentFolder.name).path as NSString).abbreviatingWithTildeInPath
                    }
                }
        }
    }

    private var attachments: some View {
        SettingsRow(label: appearance.text("settings.mailStore.attachments")) {
            ToggleSwitch(isOn: Binding(get: { state.mailStore.attachments }, set: { value in
                state.setStoreAttachments(value)
                settle()
            }), labelKey: "settings.mailStore.attachments")
        }
    }

    private var limit: some View {
        let current = state.mailStore.limit
        return SettingsRow(label: appearance.text("settings.mailStore.limit")) {
            ChoiceButton(label: appearance.text(current.key)) {
                MailStoreLimit.allCases.map { option in
                    .row(MenuItem(id: option.rawValue, label: appearance.text(option.key),
                                  check: option == current ? appearance.text(SettingsKeys.menuCheck) : nil) {
                        state.setStoreLimit(option)
                        settle()
                    })
                }
            }
        }
    }

    private var folder: some View {
        let custom = state.mailStore.folder != nil
        return SettingsRow(label: appearance.text("settings.mailStore.folder"),
                           sub: custom ? folderName.map { Text(verbatim: $0) } : nil, line: false) {
            ChoiceButton(label: appearance.text(custom ? "settings.mailStore.folder.custom" : "settings.mailStore.folder.default")) {
                [
                    .row(MenuItem(id: "folder.default", label: appearance.text("settings.mailStore.folder.default"),
                                  check: custom ? nil : appearance.text(SettingsKeys.menuCheck)) { relocate(to: nil) }),
                    .row(MenuItem(id: "folder.custom", label: appearance.text("settings.mailStore.folder.custom"),
                                  check: custom ? appearance.text(SettingsKeys.menuCheck) : nil) { choose() }),
                ]
            }
        }
    }

    private func settle() {
        Task { await context.inbox.settleAttachments() }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.appearance = state.appearance.panel
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let bookmark = AttachmentFolder.bookmark(for: url) else {
            state.notify("settings.toast.mailStoreMove", failed: true)
            return
        }
        relocate(to: bookmark)
    }

    private func relocate(to bookmark: Data?) {
        guard bookmark != state.mailStore.folder else { return }
        Task {
            let moved = await context.inbox.moveAttachments(to: bookmark) { state.setStoreFolder(bookmark) }
            if moved {
                await context.inbox.settleAttachments()
            } else {
                state.notify("settings.toast.mailStoreMove", failed: true)
            }
        }
    }
}

struct MailboxDisplayRow: View {
    @Environment(\.appearance) private var appearance
    let state: SettingsState
    let inlet: Inlet

    var body: some View {
        let current = state.display(inlet.id)
        SettingsRow(label: appearance.text("settings.account.show")) {
            ChoiceButton(label: label(current)) {
                MailboxDisplay.allCases.map { option in
                    .row(MenuItem(id: option.rawValue, label: label(option),
                                  check: option == current ? appearance.text(SettingsKeys.menuCheck) : nil) {
                        state.setDisplay(option, for: inlet.id)
                    })
                }
            }
        }
    }

    private func label(_ option: MailboxDisplay) -> Text {
        option.choice(title: state.mailboxName(inlet.id), account: inlet.account).map { Text(verbatim: $0) } ?? appearance.text("settings.account.show.own")
    }
}

struct MailboxImagesRow: View {
    @Environment(\.appearance) private var appearance
    let state: SettingsState
    let inlet: Inlet

    var body: some View {
        SettingsRow(label: appearance.text("settings.privacy.images")) {
            ToggleSwitch(isOn: Binding(get: { state.loadImages(inlet.id) }, set: { state.setLoadImages($0, for: inlet.id) }),
                         labelKey: "settings.privacy.images")
        }
    }
}

struct MailboxNameRow: View {
    @Environment(\.appearance) private var appearance
    let state: SettingsState
    let inlet: Inlet

    var body: some View {
        SettingsRow(label: appearance.text("settings.account.name")) {
            ValueField(
                text: Binding(get: { state.mailboxName(inlet.id) }, set: { state.setMailboxName($0, for: inlet.id) }),
                labelKey: "settings.account.name", prompt: appearance.text("settings.account.name.prompt"))
        }
    }
}

struct MailboxRangeRow: View {
    @Environment(\.appearance) private var appearance
    let state: SettingsState
    let inbox: InboxState
    let inlet: Inlet
    var named = false

    var body: some View {
        let offered = inbox.ranges(inlet.id)
        if offered.count > 1 {
            let current = state.range(inlet.id).resolved(in: offered)
            SettingsRow(label: label) {
                ChoiceButton(label: appearance.text(current.key)) {
                    offered.map { option in
                        .row(MenuItem(id: option.rawValue, label: appearance.text(option.key),
                                      check: option == current ? appearance.text(SettingsKeys.menuCheck) : nil) {
                            choose(option)
                        })
                    }
                }
            }
        }
    }

    private var label: Text {
        let name = appearance.string("settings.mailStore.period")
        guard named else { return Text(verbatim: name) }
        let account = inlet.account.isEmpty ? appearance.string(inlet.title) : inlet.account
        return Text(verbatim: appearance.format("settings.area.account", name, account))
    }

    private func choose(_ option: MailboxRange) {
        state.setRange(option, for: inlet.id)
        Task { await inbox.rangeChanged(inlet.id) }
    }
}

struct MailboxServerCopyRow: View {
    @Environment(\.appearance) private var appearance
    let state: SettingsState
    let inbox: InboxState
    let inlet: Inlet

    var body: some View {
        if inbox.inboxOnly(inlet.id) {
            let current = state.serverCopy(inlet.id)
            SettingsRow(label: appearance.text("settings.account.serverCopy")) {
                ChoiceButton(label: appearance.text(current.key)) {
                    ServerCopy.allCases.map { option in
                        .row(MenuItem(id: option.rawValue, label: appearance.text(option.key),
                                      check: option == current ? appearance.text(SettingsKeys.menuCheck) : nil) {
                            state.setServerCopy(option, for: inlet.id)
                        })
                    }
                }
            }
        }
    }
}

struct SignatureBlock: View {
    @Environment(\.appearance) private var appearance
    let state: SettingsState
    let inlet: Inlet
    @State private var written = false

    private var who: String { inlet.account.isEmpty ? appearance.string(inlet.title) : inlet.account }

    private var signature: MailboxSignature? {
        guard let stored = state.signature(inlet.id), written || stored.block != nil else { return nil }
        return stored
    }

    var body: some View {
        Text(verbatim: appearance.format("settings.signature.head", who))
            .font(.face(Tokens.TextSize.small))
            .foregroundStyle(appearance.color(\.inkTertiary))
            .padding(.horizontal, CGFloat(Tokens.Spacing.step16))
            .padding(.bottom, CGFloat(Tokens.Spacing.step8))
            .frame(maxWidth: .infinity, minHeight: CGFloat(Tokens.Spacing.step36), alignment: .bottomLeading)
        if let signature {
            editor(signature)
            SettingsRow(label: appearance.text("settings.signature.new"), sub: appearance.text("settings.signature.new.sub")) {
                ToggleSwitch(isOn: Binding(get: { signature.onNew }, set: { state.setSignatureOnNew($0, for: inlet.id) }),
                             labelKey: "settings.signature.new")
            }
            SettingsRow(label: appearance.text("settings.signature.above")) {
                ToggleSwitch(isOn: Binding(get: { signature.aboveQuote }, set: { state.setSignatureAboveQuote($0, for: inlet.id) }),
                             labelKey: "settings.signature.above")
            }
            SettingsRow(label: Text(verbatim: ""), line: false) {
                TextButton(label: appearance.text("settings.signature.remove"), kind: .plain) {
                    written = false
                    state.removeSignature(for: inlet.id)
                }
            }
        } else {
            BlockNote(text: appearance.text("settings.signature.empty"))
            SettingsRow(label: Text(verbatim: ""), line: false) {
                TextButton(label: appearance.text("settings.signature.create"), kind: .accent) {
                    written = true
                    state.setSignature("", for: inlet.id)
                }
            }
        }
    }

    private func editor(_ signature: MailboxSignature) -> some View {
        TextEditor(text: Binding(get: { signature.text }, set: { value in
            written = true
            state.setSignature(value, for: inlet.id)
        }))
            .scrollContentBackground(.hidden)
            .font(.face(Tokens.TextSize.body))
            .foregroundStyle(appearance.color(\.ink))
            .accessibilityLabel(Text(verbatim: appearance.format("settings.signature.area", who)))
            .padding(.vertical, CGFloat(Tokens.Spacing.step8))
            .padding(.horizontal, CGFloat(Tokens.Spacing.step12))
            .frame(minHeight: CGFloat(Tokens.Size.signatureEditorMinHeight))
            .background(RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.notice)).fill(appearance.color(\.well)))
            .padding(.horizontal, CGFloat(Tokens.Spacing.step16))
            .padding(.top, CGFloat(Tokens.Spacing.step4))
            .padding(.bottom, CGFloat(Tokens.Spacing.step8))
    }
}
