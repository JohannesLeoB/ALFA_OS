import Hub
import SwiftUI

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
