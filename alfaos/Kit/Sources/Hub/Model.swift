import Foundation

public enum Capability: String, Codable, CaseIterable, Sendable {
    case mail, calendar, contacts, files, tasks, time, documents, assistant, shipping
}

public enum DataKind: String, Codable, CaseIterable, Sendable {
    case mailboxes, messages, calendar, contacts, files, projects, tasks, time, receipts, shipments

    public var capability: Capability? {
        switch self {
        case .mailboxes, .messages: .mail
        case .calendar: .calendar
        case .contacts: .contacts
        case .files: .files
        case .projects: nil
        case .tasks: .tasks
        case .time: .time
        case .receipts: .documents
        case .shipments: .shipping
        }
    }
}

public enum Cadence: Codable, Equatable, Sendable {
    case off
    case manual
    case every(Duration)
    case push
    case hook
}

public struct Period: Equatable, Sendable {
    public var from: Date
    public var to: Date

    public init(from: Date, to: Date) {
        self.from = from
        self.to = to
    }

    public static let all = Period(from: .distantPast, to: .distantFuture)

    public func contains(_ date: Date) -> Bool { date >= from && date <= to }
}

public struct Cost: Equatable, Sendable {
    public var calls: Int
    public var bytes: Int
    public var tokens: Int

    public init(calls: Int = 0, bytes: Int = 0, tokens: Int = 0) {
        self.calls = calls
        self.bytes = bytes
        self.tokens = tokens
    }

    public static let zero = Cost()
}

public struct CostItem: Equatable, Sendable {
    public var inlet: Inlet.ID
    public var capability: Capability
    public var cost: Cost
    public var at: Date

    public init(inlet: Inlet.ID, capability: Capability, cost: Cost, at: Date) {
        self.inlet = inlet
        self.capability = capability
        self.cost = cost
        self.at = at
    }
}

public struct Person: Identifiable, Equatable, Codable, Sendable {
    public typealias ID = String
    public var id: ID
    public var name: String

    public init(id: ID, name: String) {
        self.id = id
        self.name = name
    }
}

public enum Owner: Hashable, Codable, Sendable {
    case person(Person.ID)
    case company
}

public enum SettingsTarget: Equatable, Codable, Sendable {
    case inlets
    case inlet(String)
}

public struct Hint: Equatable, Codable, Sendable {
    public static let signInExpiredText = "hint.signin.expired"

    public let text: String
    public let detail: String?
    public let fixIn: SettingsTarget?
    public let kind: FailureKind?
    public let original: Original?

    public init(text: String, detail: String? = nil, fixIn: SettingsTarget? = nil, kind: FailureKind? = nil,
                original: Original? = nil) {
        self.text = text
        self.detail = detail
        self.fixIn = fixIn
        self.kind = kind
        self.original = original
    }

    public init(text: String, classification: Classification, fixIn: SettingsTarget? = nil) {
        self.init(text: text, detail: classification.detail, fixIn: fixIn, kind: classification.kind,
                  original: classification.original)
    }

    public var code: String? { original?.label }

    public var codeKey: String? { code.map { "hint.code." + $0 } }
}

public struct Field: Identifiable, Equatable, Sendable {
    public typealias ID = String
    public var id: ID
    public var title: String
    public var secret: Bool

    public init(id: ID, title: String, secret: Bool = false) {
        self.id = id
        self.title = title
        self.secret = secret
    }
}

public struct Preset: Identifiable, Equatable, Sendable {
    public typealias ID = String
    public var id: ID
    public var title: String
    public var values: [Field.ID: String]

    public init(id: ID, title: String, values: [Field.ID: String]) {
        self.id = id
        self.title = title
        self.values = values
    }
}

public enum Way: Equatable, Sendable {
    case signIn
    case form([Field])
    case key([Field])
}

public struct Offer: Identifiable, Equatable, Sendable {
    public var id: String
    public var provider: String
    public var title: String
    public var capabilities: Set<Capability>
    public var owner: Owner
    public var way: Way
    public var preset: Preset?

    public init(id: String, provider: String, title: String, capabilities: Set<Capability>, owner: Owner,
                way: Way, preset: Preset? = nil) {
        self.id = id
        self.provider = provider
        self.title = title
        self.capabilities = capabilities
        self.owner = owner
        self.way = way
        self.preset = preset
    }
}

public enum Input: Equatable, Sendable {
    case none
    case fields([Field.ID: String])

    public var values: [Field.ID: String] {
        switch self {
        case .none: [:]
        case .fields(let values): values
        }
    }
}

public enum InletState: Equatable, Codable, Sendable {
    case created
    case signedIn
    case connecting
    case connected(probed: Date)
    case working
    case failed(Hint)
    case keychainUnreadable
    case orphaned
    case locked

    public var isConnected: Bool {
        switch self {
        case .connected, .working: true
        default: false
        }
    }
}

public struct Inlet: Identifiable, Equatable, Codable, Sendable {
    public typealias ID = String
    public var id: ID
    public var provider: String
    public var capabilities: Set<Capability>
    public var owner: Owner
    public var title: String
    public var account: String
    public var state: InletState

    public init(id: ID, provider: String, capabilities: Set<Capability>, owner: Owner, title: String,
                account: String = "", state: InletState = .created) {
        self.id = id
        self.provider = provider
        self.capabilities = capabilities
        self.owner = owner
        self.title = title
        self.account = account
        self.state = state
    }
}

public enum HubError: Error, Equatable, Sendable {
    case noInlet(DataKind)
    case provider(Hint)
    case notConnected(Inlet.ID)
    case capabilityMissing(Inlet.ID, Capability)
}

public enum SetupError: Error, Equatable, Sendable {
    case cancelled
    case probeFailed(Hint)
    case limitReached(Capability, max: Int)
    case duplicate
    case keychain(OSStatus)
}

public enum HubEvent: Equatable, Sendable {
    case inletChanged(Inlet.ID)
    case inletRemoved(Inlet.ID)
    case syncFinished(Capability, Inlet.ID)
    case newItems(DataKind)
}

public struct SyncJob: Equatable, Sendable {
    public var inlet: Inlet.ID
    public var capability: Capability
    public var startedAt: Date

    public init(inlet: Inlet.ID, capability: Capability, startedAt: Date) {
        self.inlet = inlet
        self.capability = capability
        self.startedAt = startedAt
    }
}

public struct SyncReport: Equatable, Sendable {
    public enum Result: Equatable, Sendable {
        case finished(items: Int)
        case skipped
        case failed(Hint)
    }

    public var inlet: Inlet.ID
    public var capability: Capability
    public var result: Result

    public init(inlet: Inlet.ID, capability: Capability, result: Result) {
        self.inlet = inlet
        self.capability = capability
        self.result = result
    }
}

public protocol Record: Identifiable, Sendable where ID == String {
    var inlet: Inlet.ID { get }
}

public struct MailboxRecord: Record, Equatable {
    public var id: String
    public var inlet: Inlet.ID
    public var name: String
    public var role: String

    public init(id: String, inlet: Inlet.ID, name: String, role: String) {
        self.id = id
        self.inlet = inlet
        self.name = name
        self.role = role
    }
}

public struct SyncOutcome: Sendable {
    public var deliveries: [DataKind: [any Record]]

    public init(deliveries: [DataKind: [any Record]] = [:]) {
        self.deliveries = deliveries
    }

    public var count: Int { deliveries.values.reduce(0) { $0 + $1.count } }
}

public struct WriteOrder: Sendable {
    public let inlet: Inlet.ID
    public let run: @MainActor @Sendable (WriteContext, Inlet.ID) async throws -> Void

    public init(inlet: Inlet.ID, run: @escaping @MainActor @Sendable (WriteContext, Inlet.ID) async throws -> Void) {
        self.inlet = inlet
        self.run = run
    }
}

@MainActor
public struct WriteContext {
    let core: HubCore

    public func port<P>(_ port: P.Type, for inlet: Inlet.ID) throws(HubError) -> P {
        try core.resolve(port, for: inlet)
    }
}

extension SetupError {
    public var hint: Hint {
        switch self {
        case .cancelled: Hint(text: "mail.error.cancelled")
        case .probeFailed(let hint): hint
        case .limitReached(_, let max): Hint(text: "mail.error.limit", detail: String(max))
        case .duplicate: Hint(text: "mail.error.duplicate")
        case .keychain(let status): Hint(text: "mail.error.keychain", detail: String(status))
        }
    }
}
