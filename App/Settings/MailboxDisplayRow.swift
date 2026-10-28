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
        let own = inlet.title.trimmingCharacters(in: .whitespaces)
        switch option {
        case .ownName: return own.isEmpty ? appearance.text("settings.account.show.own") : Text(verbatim: own)
        case .localPart: return Text(verbatim: MailboxDisplay.local(inlet.account))
        case .domain: return Text(verbatim: MailboxDisplay.domain(inlet.account))
        }
    }
}
