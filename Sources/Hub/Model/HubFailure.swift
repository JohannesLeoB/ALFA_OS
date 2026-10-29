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
