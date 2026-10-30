import Hub
import SwiftUI

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
