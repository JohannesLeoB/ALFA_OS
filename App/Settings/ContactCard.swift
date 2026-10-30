import Hub
import Mail
import SwiftUI

struct ContactCard: View {
    @Environment(\.appearance) private var appearance
    let context: SettingsContext

    private var contacts: ContactState { context.inbox.contacts }

    private var directory: ContactSourceState { context.inbox.directory }

    private var sources: [ContactSource] {
        directory.feeds.map(\.source) + (context.inbox.accounts.isEmpty ? [] : [ContactSource.mail])
    }

    var body: some View {
        let suggested = context.inbox.senderSuggestions
        VStack(spacing: 0) {
            if !sources.isEmpty {
                BlockHead(key: "settings.contacts.sources")
                ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
                    SettingsRow(label: appearance.text(source.kind.key),
                                sub: source.account.isEmpty ? nil : Text(verbatim: source.account), line: index < sources.count - 1) {
                        ToggleSwitch(isOn: Binding(get: { directory.isOn(source.id) }, set: { turn(source, $0) }), labelKey: source.kind.key)
                    }
                }
                BlockHead(key: "settings.contacts.saved")
            }
            ForEach(contacts.items) { contact in
                if contacts.editing == contact.id {
                    SettingsRow(label: appearance.text("settings.contacts.name")) {
                        ValueField(text: Binding(get: { contact.name }, set: { contacts.edit(contact.id, name: $0) }),
                                   labelKey: "settings.contacts.name")
                    }
                    SettingsRow(label: appearance.text("settings.contacts.address")) {
                        ValueField(text: Binding(get: { contact.address }, set: { contacts.edit(contact.id, address: $0) }),
                                   labelKey: "settings.contacts.address")
                    }
                    SettingsRow(label: Text(verbatim: "")) {
                        TextButton(label: appearance.text("settings.contacts.done"), kind: .accent) { contacts.editing = nil }
                        TextButton(label: appearance.text("settings.contacts.remove"), kind: .signal) { notify(contacts.remove(contact.id)) }
                    }
                } else {
                    SettingsRow(label: contact.name.isEmpty ? appearance.text("settings.contacts.unnamed") : Text(verbatim: contact.name),
                                sub: contact.address.isEmpty ? appearance.text("settings.contacts.noAddress") : Text(verbatim: contact.address)) {
                        TextButton(label: appearance.text("settings.contacts.edit")) { contacts.editing = contact.id }
                    }
                }
            }
            SettingsRow(label: appearance.text("settings.contacts.new"), line: !suggested.isEmpty) {
                TextButton(label: appearance.text("settings.contacts.add")) { contacts.add() }
            }
            if !suggested.isEmpty {
                BlockNote(text: appearance.text("settings.contacts.suggested"))
                ForEach(Array(suggested.enumerated()), id: \.element.id) { index, item in
                    SettingsRow(label: Text(verbatim: item.name.isEmpty ? item.address : item.name), sub: Text(verbatim: item.address),
                                line: index < suggested.count - 1) {
                        TextButton(label: appearance.text("settings.contacts.keep")) { notify(context.inbox.saveContact(item)) }
                    }
                }
            }
        }
    }

    private func turn(_ source: ContactSource, _ on: Bool) {
        directory.set(source.id, on: on)
        if on { Task { await directory.refresh() } }
    }

    private func notify(_ kind: ToastKind) {
        context.state.notify(kind.key, name: kind.name)
    }
}
