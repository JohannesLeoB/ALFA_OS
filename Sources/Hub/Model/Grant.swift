public struct Grant: Sendable {
    public let values: [String: String]

    public init(values: [String: String]) {
        self.values = values
    }
}

public struct GrantRenewal: Sendable {
    let onRenewed: @Sendable (Grant) -> Void
    let onFailed: @Sendable (any Error) -> Void

    public init(renewed: @escaping @Sendable (Grant) -> Void, failed: @escaping @Sendable (any Error) -> Void) {
        onRenewed = renewed
        onFailed = failed
    }

    public static let ignoring = GrantRenewal(renewed: { _ in }, failed: { _ in })

    public func renewed(_ grant: Grant) { onRenewed(grant) }

    public func failed(_ error: any Error) { onFailed(error) }
}

public struct KeyValues: Sendable {
    let values: [String: String]

    public init(values: [String: String]) {
        self.values = values
    }

    public subscript(id: String) -> String { values[id] ?? "" }
}

public struct KeySlot: Hashable, Sendable {
    var inlet: Inlet.ID
    var name: String

    public init(inlet: Inlet.ID, name: String) {
        self.inlet = inlet
        self.name = name
    }
}

public struct ClaudeKey: Equatable, Sendable {
    public static let defaultModel = "claude-sonnet-4-6"

    public var apiKey: String
    public var model: String

    public init(apiKey: String, model: String = ClaudeKey.defaultModel) {
        self.apiKey = apiKey
        self.model = model
    }
}
