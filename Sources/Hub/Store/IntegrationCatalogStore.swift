public struct IntegrationCatalogStore: Sendable {
    let entries: [IntegrationInfo]

    init(entries: [IntegrationInfo]) {
        self.entries = entries
    }

    public func info(_ id: String) -> IntegrationInfo? { entries.first { $0.id == id } }

    public func info(forProvider provider: String) -> IntegrationInfo? {
        entries.first { $0.providers.contains(provider) }
    }

    public static let standard = IntegrationCatalogStore(entries: [
        IntegrationInfo(
            id: "google", access: .browser, companyOwned: false, fields: [],
            areas: [IntegrationArea(id: "mail", capability: .mail), IntegrationArea(id: "contacts", capability: .contacts),
                    IntegrationArea(id: "files", capability: .files)],
            extras: [IntegrationExtra(id: "driveFolders", capability: .files, actionKey: "settings.sync.now")],
            listsAccounts: false, providers: ["google"], logo: nil),
        IntegrationInfo(
            id: "mailaccounts", access: .password, companyOwned: false, fields: [],
            areas: [IntegrationArea(id: "mail", capability: .mail)], extras: [],
            listsAccounts: true, providers: ["imap"], logo: nil),
        IntegrationInfo(
            id: "clickup", access: .key, companyOwned: false, fields: [IntegrationField(id: "token", secret: true)],
            areas: [IntegrationArea(id: "phases", capability: .tasks), IntegrationArea(id: "taskFields", capability: .tasks)],
            extras: [], listsAccounts: false, providers: ["clickup"], logo: nil),
        IntegrationInfo(
            id: "clockodo", access: .emailKey, companyOwned: false,
            fields: [IntegrationField(id: "email", secret: false), IntegrationField(id: "key", secret: true),
                     IntegrationField(id: "user", secret: false, optional: true)],
            areas: [], extras: [], listsAccounts: false, providers: ["clockodo"],
            logo: IntegrationLogo(resource: "clockodo")),
        IntegrationInfo(
            id: "claude", access: .key, companyOwned: false,
            fields: [IntegrationField(id: "key", secret: true),
                     IntegrationField(id: "model", secret: false, optional: true, fallbackKey: "settings.value.default")],
            areas: [], extras: [], listsAccounts: false, providers: ["claude"], logo: nil),
        IntegrationInfo(
            id: "airtable", access: .key, companyOwned: true,
            fields: [IntegrationField(id: "base", secret: false), IntegrationField(id: "token", secret: true)],
            areas: [IntegrationArea(id: "projects", capability: nil)], extras: [], listsAccounts: false,
            providers: ["airtable"], logo: nil),
        IntegrationInfo(
            id: "sevdesk", access: .key, companyOwned: true, fields: [IntegrationField(id: "token", secret: true)],
            areas: [], extras: [], listsAccounts: false, providers: ["sevdesk"], logo: nil),
        IntegrationInfo(
            id: "dhl", access: .key, companyOwned: true, fields: [IntegrationField(id: "key", secret: true)],
            areas: [], extras: [], listsAccounts: false, providers: ["dhl"],
            logo: IntegrationLogo(resource: "dhl")),
        IntegrationInfo(
            id: "dhlship", access: .key, companyOwned: true,
            fields: [IntegrationField(id: "key", secret: true), IntegrationField(id: "secret", secret: true),
                     IntegrationField(id: "user", secret: false), IntegrationField(id: "password", secret: true),
                     IntegrationField(id: "billing", secret: false), IntegrationField(id: "sender", secret: false, optional: true)],
            areas: [], extras: [], listsAccounts: false, providers: ["dhlship"],
            logo: IntegrationLogo(resource: "dhl")),
    ])
}
