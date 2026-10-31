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
            extras: [IntegrationExtra(id: "driveFolders", capability: .files, kind: .projectRoot, actionKey: "settings.sync.now")],
            listsAccounts: false, providers: ["google"], logo: IntegrationLogo(resource: "google", kind: .mark)),
        IntegrationInfo(
            id: "mailaccounts", access: .password, companyOwned: false, fields: [],
            areas: [IntegrationArea(id: "mail", capability: .mail)], extras: [],
            listsAccounts: true, providers: ["imap", "microsoft"], logo: IntegrationLogo(resource: "mailaccounts", kind: .mark)),
        IntegrationInfo(
            id: "clickup", access: .key, companyOwned: false, fields: [IntegrationField(id: "token", secret: true)],
            areas: [IntegrationArea(id: "phases", capability: .tasks), IntegrationArea(id: "taskFields", capability: .tasks)],
            extras: [], listsAccounts: false, providers: ["clickup"], logo: IntegrationLogo(resource: "clickup", kind: .mark)),
        IntegrationInfo(
            id: "clockodo", access: .emailKey, companyOwned: false,
            fields: [IntegrationField(id: "email", secret: false), IntegrationField(id: "key", secret: true),
                     IntegrationField(id: "user", secret: false, optional: true)],
            areas: [], extras: [], listsAccounts: false, providers: ["clockodo"],
            logo: IntegrationLogo(resource: "clockodo", kind: .full)),
        IntegrationInfo(
            id: "claude", access: .key, companyOwned: false,
            fields: [IntegrationField(id: "key", secret: true),
                     IntegrationField(id: "model", secret: false, optional: true, fallbackKey: "settings.value.default")],
            areas: [], extras: [], listsAccounts: false, providers: ["claude"],
            logo: IntegrationLogo(resource: "claude", kind: .full)),
        IntegrationInfo(
            id: "airtable", access: .key, companyOwned: true,
            fields: [IntegrationField(id: "base", secret: false), IntegrationField(id: "token", secret: true)],
            areas: [IntegrationArea(id: "projects", capability: nil)],
            extras: [IntegrationExtra(id: "cache", capability: nil, kind: .clear, actionKey: "settings.action.clear")],
            listsAccounts: false,
            providers: ["airtable"], logo: IntegrationLogo(resource: "airtable", kind: .mark)),
        IntegrationInfo(
            id: "sevdesk", access: .key, companyOwned: true, fields: [IntegrationField(id: "token", secret: true)],
            areas: [], extras: [], listsAccounts: false, providers: ["sevdesk"],
            logo: IntegrationLogo(resource: "sevdesk", kind: .full)),
        IntegrationInfo(
            id: "dhl", access: .key, companyOwned: true,
            fields: [IntegrationField(id: "key", secret: true), IntegrationField(id: "shipKey", secret: true, optional: true),
                     IntegrationField(id: "secret", secret: true, optional: true), IntegrationField(id: "user", secret: false, optional: true),
                     IntegrationField(id: "password", secret: true, optional: true),
                     IntegrationField(id: "billing", secret: false, optional: true)],
            areas: [], extras: [], listsAccounts: false, providers: ["dhl"],
            logo: IntegrationLogo(resource: "dhl", kind: .wide)),
    ])
}
