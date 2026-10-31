import Hub
import Mail
import SwiftUI

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
