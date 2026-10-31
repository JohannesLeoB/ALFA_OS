import AppKit
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
