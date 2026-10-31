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
    case newItems(DataKind)
}
