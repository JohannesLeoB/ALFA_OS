import Foundation

public struct Inlet: Identifiable, Equatable, Codable, Sendable {
    public typealias ID = String
    public var id: ID
    public var provider: String
    public var capabilities: Set<Capability>
    var owner: Owner
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

public enum InletState: Equatable, Codable, Sendable {
    case created
    case connecting
    case connected(probed: Date)
    case working
    case failed(Hint)
    case keychainUnreadable

    public var isConnected: Bool {
        switch self {
        case .connected, .working: true
        default: false
        }
    }

    var canRenew: Bool {
        switch self {
        case .failed, .keychainUnreadable: true
        default: false
        }
    }

    var isTransient: Bool {
        switch self {
        case .connecting, .working: true
        default: false
        }
    }

    var isStorable: Bool {
        switch self {
        case .created, .connected, .failed: true
        case .connecting, .working, .keychainUnreadable: false
        }
    }

    func sameKind(as other: InletState) -> Bool {
        switch (self, other) {
        case (.connected, .connected): true
        default: self == other
        }
    }

    private enum Stored: Codable {
        case created
        case signedIn
        case connecting
        case connected(probed: Date)
        case working
        case failed(Hint)
        case keychainUnreadable
        case orphaned
        case locked
    }

    public init(from decoder: any Decoder) throws {
        switch try Stored(from: decoder) {
        case .created: self = .created
        case .connecting: self = .connecting
        case .connected(let probed): self = .connected(probed: probed)
        case .working: self = .working
        case .failed(let hint): self = .failed(hint)
        case .keychainUnreadable, .orphaned, .locked: self = .keychainUnreadable
        case .signedIn: self = .connected(probed: .distantPast)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        let stored: Stored = switch self {
        case .created: .created
        case .connecting: .connecting
        case .connected(let probed): .connected(probed: probed)
        case .working: .working
        case .failed(let hint): .failed(hint)
        case .keychainUnreadable: .keychainUnreadable
        }
        try stored.encode(to: encoder)
    }
}

public enum InletEvent: Equatable, Sendable {
    case inletChanged(Inlet.ID)
    case inletRemoved(Inlet.ID)
    case syncFinished(Capability, Inlet.ID)
    case syncFailed(Capability, Inlet.ID, Hint)
    case itemsArrived(DataKind)
}

public struct Person: Identifiable, Equatable, Codable, Sendable {
    public typealias ID = String
    public var id: ID
    var name: String

    public init(id: ID, name: String) {
        self.id = id
        self.name = name
    }
}

public enum Owner: Hashable, Codable, Sendable {
    case person(Person.ID)
    case company
}

public enum Capability: String, Codable, CaseIterable, Sendable {
    case mail, calendar, contacts, files, tasks, time, documents, assistant, shipping
}

public enum DataKind: String, Codable, CaseIterable, Sendable {
    case mailboxes, messages, calendar, contacts, files, projects, tasks, time, receipts, shipments

    var capability: Capability? {
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

public enum CadenceChoice: String, CaseIterable, Sendable {
    case automatic
    case off
    case manual
    case seconds30
    case minute1
    case minutes5
    case minutes15
    case minutes30
    case hour1

    public var key: String { "settings.cadence." + rawValue }

    public var cadence: Cadence {
        switch self {
        case .automatic: .push
        case .off: .off
        case .manual: .manual
        case .seconds30: .every(.seconds(30))
        case .minute1: .every(.seconds(60))
        case .minutes5: .every(.seconds(300))
        case .minutes15: .every(.seconds(900))
        case .minutes30: .every(.seconds(1800))
        case .hour1: .every(.seconds(3600))
        }
    }

    public static func offered(for capability: Capability) -> [CadenceChoice] {
        if capability == .mail { return [.automatic, .minute1, .minutes5, .minutes15, .minutes30, .hour1, .manual] }
        return allCases.filter { $0 != .automatic }
    }

    init?(_ cadence: Cadence) {
        guard let match = Self.allCases.first(where: { $0.cadence == cadence }) else { return nil }
        self = match
    }
}

public enum LinkState: String, CaseIterable, Sendable {
    case connected
    case connecting
    case working
    case notConnected
    case failed
    case unreadable

    public var key: String { "settings.link." + rawValue }

    public init(_ state: InletState) {
        switch state {
        case .created: self = .notConnected
        case .connecting: self = .connecting
        case .connected: self = .connected
        case .working: self = .working
        case .failed: self = .failed
        case .keychainUnreadable: self = .unreadable
        }
    }

    public var isBad: Bool { self == .failed || self == .unreadable }

    var isActive: Bool { self == .connected || self == .working }

    public var canDisconnect: Bool { isActive || self == .failed }

    private var severity: Int {
        switch self {
        case .failed: 7
        case .unreadable: 6
        case .connecting: 4
        case .working: 3
        case .connected: 1
        case .notConnected: 0
        }
    }

    static func combined(_ states: [LinkState]) -> LinkState {
        states.max { $0.severity < $1.severity } ?? .notConnected
    }
}

public enum LinkNote: Equatable, Sendable {
    case checked(Date)
    case failed(at: Date?, lastOK: Date?)
    case signingIn
    case working(areaKey: String, done: Int, total: Int)
}

public enum HubFailure: Error, Equatable, Sendable {
    case provider(Hint)
    case notConnected(Inlet.ID)
    case capabilityMissing(Inlet.ID, Capability)
}

public struct KeyFieldFailure: Error, Equatable, Sendable {
    let field: String

    public init(field: String) {
        self.field = field
    }
}

enum KeychainFailure: Error, Equatable, Sendable {
    case status(Int32)
}

public enum SetupFailure: Error, Equatable, Sendable {
    case cancelled
    case probeFailed(Hint)
    case duplicate
    case keychain(Int32)

    public var hint: Hint {
        switch self {
        case .cancelled: Hint(text: "hub.error.cancelled")
        case .probeFailed(let hint): hint
        case .duplicate: Hint(text: "hub.error.duplicate")
        case .keychain(let status): Hint(text: "hub.error.keychain", detail: String(status))
        }
    }
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

    public static func failed(_ error: Error) -> Hint {
        Hint(text: HintEngine.failedText, detail: String(describing: error))
    }

    public var code: String? { original?.label }

    public var codeKey: String? { code.map { "hint.code." + $0 } }
}

public struct ProbeResult: Equatable, Sendable {
    public var account: String
    public var rejection: Hint?

    public init(account: String, rejection: Hint? = nil) {
        self.account = account
        self.rejection = rejection
    }
}

public struct Classification: Equatable, Sendable {
    public var kind: FailureKind
    public var original: Original

    public init(kind: FailureKind, original: Original) {
        self.kind = kind
        self.original = original
    }

    public var detail: String? {
        if let text = original.text, !text.isEmpty { return text }
        return original.status.map { "HTTP \($0)" }
    }

    public static func generic(_ error: Error) -> Classification {
        if let url = error as? URLError {
            return Classification(kind: .transient, original: Original(
                provider: "network", code: "URLError." + String(url.code.rawValue), text: url.localizedDescription,
                extra: ["domain": URLError.errorDomain]))
        }
        return Classification(kind: .rejected, original: Original(provider: "unknown", text: String(describing: error)))
    }
}

public struct Original: Equatable, Codable, Sendable {
    public var provider: String
    public var status: Int?
    public var code: String?
    public var text: String?
    public var extra: [String: String]

    public init(provider: String, status: Int? = nil, code: String? = nil, text: String? = nil,
                extra: [String: String] = [:]) {
        self.provider = provider
        self.status = status
        self.code = code
        self.text = text
        self.extra = extra
    }

    public var label: String {
        var parts = [provider]
        if let status { parts.append(String(status)) }
        if let code { parts.append(code) }
        return parts.joined(separator: ".")
    }
}

public enum FailureKind: String, Codable, Equatable, Sendable {
    case transient
    case signIn
    case rejected
}
