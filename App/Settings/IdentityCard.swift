import AppKit
import Core
import Design
import Hub
import SwiftUI

struct IdentityCard: View {
    @Environment(\.appearance) private var appearance
    let context: SettingsContext

    private var profile: UserProfile { context.state.profile }

    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(label: appearance.text("settings.identity.name")) {
                ValueField(text: bind(\.name), labelKey: "settings.identity.name", prompt: appearance.text(SettingsKeys.valueEmpty))
            }
            SettingsRow(label: appearance.text("settings.identity.role")) {
                ValueField(text: bind(\.role), labelKey: "settings.identity.role", prompt: appearance.text(SettingsKeys.valueEmpty))
            }
            SettingsRow(label: appearance.text("settings.identity.code")) {
                ValueField(
                    text: bind(\.code), labelKey: "settings.identity.code",
                    prompt: Initials.from(profile.name).isEmpty ? appearance.text(SettingsKeys.valueEmpty) : Text(verbatim: Initials.from(profile.name)))
            }
            SettingsRow(label: appearance.text("settings.identity.phone")) {
                ValueField(text: bind(\.phone), labelKey: "settings.identity.phone", prompt: appearance.text(SettingsKeys.valueEmpty))
            }
            SettingsRow(label: appearance.text("settings.identity.birthdays")) {
                ToggleSwitch(
                    isOn: Binding(get: { profile.birthdays }, set: { value in context.state.updateProfile { $0.birthdays = value } }),
                    labelKey: "settings.identity.birthdays")
            }
            BlockHead(key: "settings.identity.account")
            SettingsRow(label: appearance.text("settings.identity.signOut"), sub: Text(verbatim: signOutSub), line: false) {
                ConfirmPill(
                    label: appearance.text("settings.identity.signOut.action"),
                    question: appearance.text("settings.signOut.question"),
                    yes: appearance.text("settings.identity.signOut.action"),
                    no: appearance.text("confirm.no"),
                    holdHint: Text(verbatim: appearance.format("settings.confirm.hold", appearance.string("settings.identity.signOut.action"))),
                    showsProgress: false,
                    onYes: { signOut() }
                )
                .rowPill()
            }
        }
    }

    private var signOutSub: String {
        let names = context.readings
            .filter { [.connected, .working, .failed, .connecting].contains($0.state) }
            .map { appearance.string($0.info.nameKey) }
        switch names.count {
        case 0: return appearance.string("settings.identity.signOut.sub.none")
        case 1: return appearance.format("settings.identity.signOut.sub.one", names[0])
        default: return appearance.format("settings.identity.signOut.sub.other", String(names.count), names.joined(separator: ", "))
        }
    }

    private func bind(_ path: WritableKeyPath<UserProfile, String>) -> Binding<String> {
        Binding(get: { profile[keyPath: path] }, set: { value in context.state.updateProfile { $0[keyPath: path] = value } })
    }

    private func signOut() {
        Task {
            guard await context.flow.signOut() else { return }
            context.state.notify("settings.signOut.done")
            try? await Task.sleep(for: .seconds(Tokens.Duration.toast))
            await AppRelaunch.run()
        }
    }
}

enum AppRelaunch {
    @MainActor
    static func run() async {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        _ = try? await NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration)
        NSApp.terminate(nil)
    }
}
