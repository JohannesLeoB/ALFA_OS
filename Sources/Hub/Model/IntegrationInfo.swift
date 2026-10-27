public struct IntegrationInfo: Identifiable, Equatable, Sendable {
    public let id: String
    public let access: IntegrationAccess
    public let companyOwned: Bool
    public let fields: [IntegrationField]
    let areas: [IntegrationArea]
    public let extras: [IntegrationExtra]
    public let listsAccounts: Bool
    public let providers: [String]
    public let logo: IntegrationLogo?

    init(id: String, access: IntegrationAccess, companyOwned: Bool, fields: [IntegrationField],
                areas: [IntegrationArea], extras: [IntegrationExtra], listsAccounts: Bool, providers: [String],
                logo: IntegrationLogo?) {
        self.id = id
        self.access = access
        self.companyOwned = companyOwned
        self.fields = fields
        self.areas = areas
        self.extras = extras
        self.listsAccounts = listsAccounts
        self.providers = providers
        self.logo = logo
    }

    public var nameKey: String { "settings.service." + id + ".name" }

    public var useKey: String { "settings.service." + id + ".use" }

    public func fieldKey(_ field: IntegrationField) -> String { "settings.service." + id + ".field." + field.id }

    public func areaKey(_ area: IntegrationArea) -> String { "settings.service." + id + ".area." + area.id }

    public func extraKey(_ extra: IntegrationExtra) -> String { "settings.service." + id + ".extra." + extra.id }
}

public enum IntegrationAccess: String, Sendable {
    case browser
    case password
    case key
    case emailKey

    public var key: String { "settings.access." + rawValue }
}

public struct IntegrationArea: Equatable, Sendable {
    let id: String
    let capability: Capability?

    init(id: String, capability: Capability?) {
        self.id = id
        self.capability = capability
    }
}

public struct IntegrationExtra: Equatable, Sendable {
    public let id: String
    public let capability: Capability
    public let actionKey: String

    init(id: String, capability: Capability, actionKey: String) {
        self.id = id
        self.capability = capability
        self.actionKey = actionKey
    }
}

public struct IntegrationField: Equatable, Sendable {
    public let id: String
    public let secret: Bool
    let optional: Bool
    public let fallbackKey: String?

    init(id: String, secret: Bool, optional: Bool = false, fallbackKey: String? = nil) {
        self.id = id
        self.secret = secret
        self.optional = optional
        self.fallbackKey = fallbackKey
    }
}

public struct IntegrationLogo: Equatable, Sendable {
    public let resource: String
    public let fileExtension: String

    init(resource: String, fileExtension: String) {
        self.resource = resource
        self.fileExtension = fileExtension
    }
}

public struct IntegrationValues: Equatable, Sendable {
    public var text: [String: String]
    public var held: Set<String>

    public static let none = IntegrationValues(text: [:], held: [])
}
