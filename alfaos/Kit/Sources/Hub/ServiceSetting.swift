import Foundation

public enum ServiceSettingKind: Equatable, Sendable {
    case toggle
    case choice([String])
    case text
    case number
    case mapping
}

public enum ServiceSettingOwner: String, Codable, Sendable {
    case person
    case company
    case device
}

public struct ServiceSetting: Identifiable, Equatable, Sendable {
    public let id: String
    public let kind: ServiceSettingKind
    public let owner: ServiceSettingOwner

    public init(id: String, kind: ServiceSettingKind, owner: ServiceSettingOwner) {
        self.id = id
        self.kind = kind
        self.owner = owner
    }

    func accepts(_ value: ServiceValue) -> Bool {
        switch (kind, value) {
        case (.toggle, .toggle), (.text, .text), (.mapping, .mapping): true
        case (.number, .number(let number)): number.isFinite
        case (.choice(let options), .choice(let picked)): options.contains(picked)
        default: false
        }
    }
}

public enum ServiceValue: Codable, Equatable, Sendable {
    case toggle(Bool)
    case choice(String)
    case text(String)
    case number(Double)
    case mapping([String: String])
}

public enum SettingError: Error, Equatable, Sendable {
    case unknownInlet(Inlet.ID)
    case unknownSetting(String)
    case wrongKind(String)
    case notAnOption(String)
    case notStored(String)
}
