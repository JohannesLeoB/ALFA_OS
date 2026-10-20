import Foundation

public enum ServiceGroup: String, CaseIterable, Sendable {
    case personal
    case company

    public var key: String { "settings.service.group." + rawValue }
}

public enum ServiceAccess: String, Sendable {
    case browser
    case password
    case key
    case emailKey

    public var key: String { "settings.access." + rawValue }
}

public struct ServiceField: Equatable, Sendable {
    public let id: String
    public let secret: Bool
    public let optional: Bool
    public let fallbackKey: String?

    init(id: String, secret: Bool, optional: Bool = false, fallbackKey: String? = nil) {
        self.id = id
        self.secret = secret
        self.optional = optional
        self.fallbackKey = fallbackKey
    }
}

public struct ServiceArea: Equatable, Sendable {
    public let id: String
    public let capability: Capability?
}

public enum ServiceExtraAction: Equatable, Sendable {
    case syncNow(Capability)
    case clearCache
}

public struct ServiceExtra: Equatable, Sendable {
    public let id: String
    public let action: ServiceExtraAction
    public let actionKey: String
}

public struct ServiceLogo: Equatable, Sendable {
    public let resource: String
    public let fileExtension: String
}

public struct ServiceInfo: Identifiable, Equatable, Sendable {
    public let id: String
    public let group: ServiceGroup
    public let access: ServiceAccess
    public let companyOwned: Bool
    public let personOnly: Bool
    public let fields: [ServiceField]
    public let areas: [ServiceArea]
    public let extras: [ServiceExtra]
    public let hasNote: Bool
    public let listsAccounts: Bool
    public let providers: [String]
    public let logo: ServiceLogo?

    public var nameKey: String { "settings.service." + id + ".name" }
    public var useKey: String { "settings.service." + id + ".use" }
    public var noteKey: String { "settings.service." + id + ".note" }
    public func fieldKey(_ field: ServiceField) -> String { "settings.service." + id + ".field." + field.id }
    public func areaKey(_ area: ServiceArea) -> String { "settings.service." + id + ".area." + area.id }
    public func extraKey(_ extra: ServiceExtra) -> String { "settings.service." + id + ".extra." + extra.id }
}

public enum ServiceCatalog {
    private static let syncNowKey = "settings.sync.now"
    private static let clearKey = "settings.extra.clear"

    public static let all: [ServiceInfo] = [
        ServiceInfo(id: "google", group: .personal, access: .browser, companyOwned: false, personOnly: false,
                    fields: [],
                    areas: [ServiceArea(id: "mail", capability: .mail), ServiceArea(id: "contacts", capability: .contacts),
                            ServiceArea(id: "files", capability: .files)],
                    extras: [ServiceExtra(id: "driveFolders", action: .syncNow(.files), actionKey: syncNowKey)],
                    hasNote: true, listsAccounts: false, providers: ["google"], logo: nil),
        ServiceInfo(id: "mailaccounts", group: .personal, access: .password, companyOwned: false, personOnly: false,
                    fields: [], areas: [], extras: [], hasNote: false, listsAccounts: true, providers: ["imap"], logo: nil),
        ServiceInfo(id: "clickup", group: .personal, access: .key, companyOwned: false, personOnly: false,
                    fields: [ServiceField(id: "token", secret: true)],
                    areas: [ServiceArea(id: "phases", capability: .tasks), ServiceArea(id: "taskFields", capability: .tasks)],
                    extras: [], hasNote: false, listsAccounts: false, providers: ["clickup"], logo: nil),
        ServiceInfo(id: "clockodo", group: .personal, access: .emailKey, companyOwned: false, personOnly: true,
                    fields: [ServiceField(id: "email", secret: false), ServiceField(id: "key", secret: true),
                             ServiceField(id: "user", secret: false, optional: true)],
                    areas: [], extras: [], hasNote: false, listsAccounts: false, providers: ["clockodo"],
                    logo: ServiceLogo(resource: "clockodo", fileExtension: "png")),
        ServiceInfo(id: "claude", group: .personal, access: .key, companyOwned: false, personOnly: false,
                    fields: [ServiceField(id: "key", secret: true),
                             ServiceField(id: "model", secret: false, optional: true, fallbackKey: "settings.value.default")],
                    areas: [], extras: [], hasNote: false, listsAccounts: false, providers: ["claude"], logo: nil),
        ServiceInfo(id: "airtable", group: .company, access: .key, companyOwned: true, personOnly: false,
                    fields: [ServiceField(id: "base", secret: false), ServiceField(id: "token", secret: true)],
                    areas: [ServiceArea(id: "projects", capability: nil)],
                    extras: [ServiceExtra(id: "cache", action: .clearCache, actionKey: clearKey)],
                    hasNote: false, listsAccounts: false, providers: ["airtable"], logo: nil),
        ServiceInfo(id: "sevdesk", group: .company, access: .key, companyOwned: true, personOnly: false,
                    fields: [ServiceField(id: "token", secret: true)],
                    areas: [], extras: [], hasNote: false, listsAccounts: false, providers: ["sevdesk"], logo: nil),
        ServiceInfo(id: "dhl", group: .company, access: .key, companyOwned: true, personOnly: false,
                    fields: [ServiceField(id: "key", secret: true)],
                    areas: [], extras: [], hasNote: false, listsAccounts: false, providers: ["dhl"],
                    logo: ServiceLogo(resource: "dhl", fileExtension: "svg")),
        ServiceInfo(id: "dhlship", group: .company, access: .key, companyOwned: true, personOnly: false,
                    fields: [ServiceField(id: "key", secret: true)],
                    areas: [], extras: [], hasNote: false, listsAccounts: false, providers: ["dhlship"],
                    logo: ServiceLogo(resource: "dhl", fileExtension: "svg")),
        ServiceInfo(id: "happa", group: .company, access: .key, companyOwned: true, personOnly: false,
                    fields: [ServiceField(id: "key", secret: true)],
                    areas: [], extras: [], hasNote: false, listsAccounts: false, providers: ["happa"], logo: nil)
    ]

    public static func info(_ id: String) -> ServiceInfo? { all.first { $0.id == id } }

    public static func info(forProvider provider: String) -> ServiceInfo? { all.first { $0.providers.contains(provider) } }

    public static func services(in group: ServiceGroup) -> [ServiceInfo] { all.filter { $0.group == group } }

    public static var inventory: [ServiceInfo] { all.filter { !$0.listsAccounts } }

    public static let ownPerson = Owner.person("")

    public static func offer(for info: ServiceInfo) -> Offer? {
        KeyProviders.standard.first { $0.id == info.id }?.offer
    }
}
