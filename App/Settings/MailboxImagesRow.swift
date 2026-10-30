import Hub
import SwiftUI

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
