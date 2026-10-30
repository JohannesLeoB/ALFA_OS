import Assistant
import Google
import Hub
import Mail
import Shell

@MainActor
struct SettingsContext {
    let state: SettingsState
    let catalog: IntegrationCatalogStore
    let setup: any SetupPort
    let rules: any RulesPort
    let keychain: any KeychainPort
    let flow: AccountFlow
    let privacy: AssistantPrivacy
    let inbox: InboxState
    let desk: DeskState
    let conversation: ChatState
    let tiles: TileFocus
    let access: any AccessPort
    let roots: DriveRootStore
    let clearCache: () -> Void

    var readings: [IntegrationReading] { IntegrationReadEngine.readAll(catalog, setup: setup, rules: rules) }

    func syncNow(_ inlet: Inlet.ID, _ capability: Capability) async -> Bool {
        let before = rules.lastSync(inlet, capability)
        await rules.syncNow(inlet, capability)
        return rules.lastSync(inlet, capability) != before
    }
}

enum SettingsKeys {
    static let failedUnknown = "settings.failed.unknown"
    static let valueEmpty = "settings.value.empty"
    static let menuCheck = "settings.menu.check"
}
