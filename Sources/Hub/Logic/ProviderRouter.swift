struct ProviderRouter: Sendable {
    private let providers: [String: any ProviderPort]

    init(_ providers: [any ProviderPort]) {
        var table: [String: any ProviderPort] = [:]
        for provider in providers { table[provider.id] = provider }
        self.providers = table
    }

    func provider(_ id: String) -> (any ProviderPort)? { providers[id] }

    func classify(_ error: any Error, provider id: String?) -> Classification {
        guard let id, let provider = providers[id] else { return Classification.generic(error) }
        return provider.classify(error)
    }
}
