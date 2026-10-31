import Foundation

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
    public let capability: Capability?
    public let kind: IntegrationExtraKind
    public let actionKey: String

    init(id: String, capability: Capability?, kind: IntegrationExtraKind, actionKey: String) {
        self.id = id
        self.capability = capability
        self.kind = kind
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
    public enum Kind: Sendable {
        case full
        case wide
        case mark
    }

    public let resource: String
    public let kind: Kind

    init(resource: String, kind: Kind) {
        self.resource = resource
        self.kind = kind
    }
}

public struct IntegrationValues: Equatable, Sendable {
    public var text: [String: String]

    public static let none = IntegrationValues(text: [:])
}

public enum IntegrationExtraKind: Sendable {
    case projectRoot
    case clear
}

public struct IntegrationReading: Identifiable, Equatable, Sendable {
    public var info: IntegrationInfo
    public var state: LinkState
    public var note: LinkNote?
    public var hint: Hint?
    public var inlets: [Inlet]
    public var offers: [Offer]
    public var areas: [AreaReading]
    public var heldSlots: Set<String> = []

    public var id: String { info.id }

    public var asksReconnect: Bool { state.isActive }

    public var lead: Inlet? { inlets.first { LinkState($0.state) == state } ?? inlets.first }

    public var leadAddress: String? {
        guard let lead, lead.capabilities.contains(.mail), !lead.account.isEmpty else { return nil }
        return lead.account
    }

    public var step: IntegrationStep {
        let lead = lead
        switch state {
        case .connected, .working, .failed, .unreadable:
            return lead.map { .renew($0.id) } ?? .none
        case .notConnected:
            return offers.isEmpty ? .none : .add(offers)
        case .connecting:
            return .none
        }
    }
}

public enum IntegrationStep: Equatable, Sendable {
    case add([Offer])
    case renew(Inlet.ID)
    case none
}

public struct AreaReading: Identifiable, Equatable, Sendable {
    public var area: IntegrationArea
    public var inlet: Inlet.ID
    public var account: String
    public var capability: Capability
    public var choice: CadenceChoice
    public var lastSync: Date?
    public var running: Bool

    public var id: String { inlet + "|" + area.id }
}

public enum SettingsSection: String, CaseIterable, Sendable, Identifiable {
    case identity
    case appearance
    case companyData
    case folders
    case templates
    case integrations
    case keyInventory
    case contacts
    case privacy
    case system
    case imprint

    public var id: String { rawValue }

    var group: SettingsGroup {
        switch self {
        case .identity, .appearance: .me
        case .companyData: .company
        case .folders, .templates: .folders
        case .integrations, .keyInventory, .contacts: .connections
        case .privacy, .system, .imprint: .protection
        }
    }

    public var key: String { "settings.section." + rawValue }

    public var detailKey: String? {
        switch self {
        case .folders, .keyInventory, .contacts, .privacy: nil
        default: "settings.section." + rawValue + ".detail"
        }
    }
}

public enum SettingsGroup: String, CaseIterable, Sendable {
    case me
    case company
    case folders
    case connections
    case protection

    public var key: String { "settings.group." + rawValue }

    public var symbol: String {
        switch self {
        case .me: "person"
        case .company: "building"
        case .folders: "folder"
        case .connections: "plug"
        case .protection: "system"
        }
    }

    public var opening: String {
        switch self {
        case .me: SettingsSection.identity.rawValue
        case .company: SettingsSection.companyData.rawValue
        case .folders: SettingsSection.folders.rawValue
        case .connections: "google"
        case .protection: SettingsSection.privacy.rawValue
        }
    }

    public var sections: [SettingsSection] { SettingsSection.allCases.filter { $0.group == self } }
}

public enum SettingsLabel: String, CaseIterable, Sendable {
    case version
    case branch
    case database
    case diagnosis

    public var key: String { "settings.label." + rawValue }
}

public enum SettingsTarget: Equatable, Codable, Sendable {
    case inlet(String)
}
