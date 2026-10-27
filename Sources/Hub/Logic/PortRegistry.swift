public struct PortRegistry: Sendable {
    private var specs: [PortSpec] = []

    public init() {}

    public mutating func register<P>(
        _ type: P.Type,
        capability: Capability,
        wrap: @escaping @Sendable (P, CostMeter) -> P = { port, _ in port },
        sync: (@Sendable (P, Inlet.ID) async throws -> SyncOutcome)? = nil
    ) {
        let make: @Sendable (any ProviderPort, Inlet, Grant, CostMeter, GrantRenewal) throws -> Any = { provider, inlet, grant, meter, renewal in
            wrap(try provider.adapter(P.self, for: inlet, grant, renewal: renewal), meter)
        }
        let run: @Sendable (any ProviderPort, Inlet, Grant, CostMeter, GrantRenewal) async throws -> SyncOutcome = {
            provider, inlet, grant, meter, renewal in
            guard let sync else { return SyncOutcome() }
            return try await sync(wrap(try provider.adapter(P.self, for: inlet, grant, renewal: renewal), meter), inlet.id)
        }
        let key = ObjectIdentifier(type)
        specs.removeAll { $0.key == key }
        specs.append(PortSpec(key: key, capability: capability, make: make, run: run))
    }

    func spec(for type: Any.Type) -> PortSpec? {
        let key = ObjectIdentifier(type)
        return specs.first { $0.key == key }
    }

    func spec(for capability: Capability) -> PortSpec? {
        specs.first { $0.capability == capability }
    }
}

struct PortSpec: Sendable {
    let key: ObjectIdentifier
    let capability: Capability
    let make: @Sendable (any ProviderPort, Inlet, Grant, CostMeter, GrantRenewal) throws -> Any
    let run: @Sendable (any ProviderPort, Inlet, Grant, CostMeter, GrantRenewal) async throws -> SyncOutcome
}
