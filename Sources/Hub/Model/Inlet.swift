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

    var canRenew: Bool {
        switch self {
        case .failed, .keychainUnreadable: true
        default: false
        }
    }
}

public enum InletEvent: Equatable, Sendable {
    case inletChanged(Inlet.ID)
    case inletRemoved(Inlet.ID)
    case syncFinished(Capability, Inlet.ID)
    case syncFailed(Capability, Inlet.ID, Hint)
    case newItems(DataKind)
}
