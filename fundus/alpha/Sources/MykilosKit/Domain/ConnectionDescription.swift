import Foundation

public enum ConnectionRole: String, Sendable, CaseIterable {
    case projectTruth
    case files
    case mail
    case calendar
    case contacts
    case tasks
    case time
    case money
    case assistant
}

public enum ConnectionText: Equatable, Sendable {
    case key(String)
    case verbatim(String)
}

public enum ConnectionFieldKind: String, Sendable, CaseIterable {
    case secret
    case identifier
    case address
    case choice
}

public enum ConnectionFieldStorage: String, Sendable, CaseIterable {
    case keychain
    case profile
}

public struct ConnectionFieldFormat: Equatable, Sendable {
    public let prefix: String?
    public let minimumLength: Int?
    public let maximumLength: Int?

    public init(prefix: String? = nil, minimumLength: Int? = nil, maximumLength: Int? = nil) {
        self.prefix = prefix
        self.minimumLength = minimumLength
        self.maximumLength = maximumLength
    }

    public func accepts(_ value: String) -> Bool {
        if let prefix, value.hasPrefix(prefix) == false { return false }
        if let minimumLength, value.count < minimumLength { return false }
        if let maximumLength, value.count > maximumLength { return false }
        return true
    }
}

public struct ConnectionField: Identifiable, Equatable, Sendable {
    public let key: String
    public let label: ConnectionText
    public let placeholder: ConnectionText?
    public let kind: ConnectionFieldKind
    public let isRequired: Bool
    public let format: ConnectionFieldFormat?
    public let storage: ConnectionFieldStorage
    public let defaultValue: String?
    public let choices: [String]
    public let isShown: Bool
    public var id: String { key }

    public init(key: String, label: ConnectionText, placeholder: ConnectionText? = nil,
                kind: ConnectionFieldKind, isRequired: Bool = true, format: ConnectionFieldFormat? = nil,
                storage: ConnectionFieldStorage = .keychain, defaultValue: String? = nil,
                choices: [String] = [], isShown: Bool = true) {
        self.key = key
        self.label = label
        self.placeholder = placeholder
        self.kind = kind
        self.isRequired = isRequired
        self.format = format
        self.storage = storage
        self.defaultValue = defaultValue
        self.choices = choices
        self.isShown = isShown
    }
}

public struct ConnectionExtra: Identifiable, Equatable, Sendable {
    public enum Kind: String, Sendable, CaseIterable {
        case action
        case list
    }

    public let id: String
    public let kind: Kind
    public let label: ConnectionText
    public let actionLabel: ConnectionText?
    public let needsConnection: Bool
    public let hint: ConnectionText?
    public let resultSome: ConnectionText?
    public let resultNone: ConnectionText?

    public init(id: String, kind: Kind, label: ConnectionText, actionLabel: ConnectionText? = nil, needsConnection: Bool = false,
                hint: ConnectionText? = nil, resultSome: ConnectionText? = nil, resultNone: ConnectionText? = nil) {
        self.id = id
        self.kind = kind
        self.label = label
        self.actionLabel = actionLabel
        self.needsConnection = needsConnection
        self.hint = hint
        self.resultSome = resultSome
        self.resultNone = resultNone
    }
}

public enum ConnectionState: Equatable, Sendable {
    case notConnected
    case connecting
    case connected
    case working
    case failed(String)
}

public struct ConnectionDescription: Identifiable, Equatable, Sendable {
    public let id: String
    public let roles: [ConnectionRole]
    public let title: ConnectionText
    public let heading: ConnectionText
    public let fields: [ConnectionField]
    public let extras: [ConnectionExtra]
    public let notes: [ConnectionText]
    public let checksWithProvider: Bool
    public let isPrivate: Bool
    public let privateMark: ConnectionText?
    public let usage: ConnectionText?
    public let directions: [ConnectionRole: ConnectionDirection]
    public let access: ConnectionAccess
    public let syncWay: ConnectionSyncWay

    public init(id: String, roles: [ConnectionRole], title: ConnectionText, heading: ConnectionText? = nil, fields: [ConnectionField],
                extras: [ConnectionExtra] = [], notes: [ConnectionText] = [], checksWithProvider: Bool, isPrivate: Bool = false,
                privateMark: ConnectionText? = nil, usage: ConnectionText? = nil,
                directions: [ConnectionRole: ConnectionDirection] = [:], access: ConnectionAccess = .none,
                syncWay: ConnectionSyncWay = .manualOnly) {
        self.id = id
        self.roles = roles
        self.title = title
        self.heading = heading ?? title
        self.fields = fields
        self.extras = extras
        self.notes = notes
        self.checksWithProvider = checksWithProvider
        self.isPrivate = isPrivate
        self.privateMark = privateMark
        self.usage = usage
        self.directions = directions
        self.access = access
        self.syncWay = syncWay
    }

    public var requiredKeys: [String] {
        fields.filter { $0.isRequired && $0.storage == .keychain }.map(\.key)
    }
}
