import Design
import Hub
import SwiftUI

struct AppearanceCard: View {
    @Environment(\.appearance) private var appearance
    @Environment(\.narrowCard) private var narrow
    let state: SettingsState

    var body: some View {
        VStack(spacing: 0) {
            if narrow {
                ChoiceRow(
                    labelKey: "settings.appearance.label", current: state.appearance, choices: AppearanceChoice.allCases,
                    key: { $0.key }, pick: { state.setAppearance($0) })
            } else {
                SettingsRow(label: appearance.text("settings.appearance.label")) {
                    SegmentedControl(
                        options: AppearanceChoice.allCases.map { SegmentOption(id: $0, label: appearance.text($0.key)) },
                        selection: Binding(get: { state.appearance }, set: { state.setAppearance($0) }))
                }
            }
            SettingsRow(label: appearance.text("settings.appearance.foreign")) {
                SettingsValue(text: appearance.text("settings.appearance.foreign.value"))
            }
            ChoiceRow(
                labelKey: "settings.start.label", current: state.destination, choices: StartDestination.allCases,
                key: { $0.key }, pick: { state.setDestination($0) })
            SettingsRow(label: appearance.text("settings.lock.label")) {
                ToggleSwitch(isOn: Binding(get: { state.lockOn }, set: { state.setLockOn($0) }), labelKey: "settings.lock.label")
            }
            ChoiceRow(
                labelKey: "settings.lock.after", current: state.lockDelay, choices: LockDelay.allCases,
                key: { $0.key }, pick: { state.setLockDelay($0) })
        }
    }
}

struct ChoiceRow<Choice: Hashable>: View {
    @Environment(\.appearance) private var appearance
    let labelKey: String
    var line = true
    let current: Choice
    let choices: [Choice]
    let key: (Choice) -> String
    let pick: (Choice) -> Void

    var body: some View {
        SettingsRow(label: appearance.text(labelKey), line: line) {
            ChoiceButton(label: appearance.text(key(current))) {
                choices.map { choice in
                    .row(MenuItem(id: key(choice), label: appearance.text(key(choice)),
                                  check: choice == current ? appearance.text(SettingsKeys.menuCheck) : nil) {
                        pick(choice)
                    })
                }
            }
        }
    }
}
