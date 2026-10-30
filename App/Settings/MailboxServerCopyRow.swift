import Hub
import Mail
import SwiftUI

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
