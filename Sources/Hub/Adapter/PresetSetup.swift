@MainActor
final class PresetSetup: SetupPort {
    private let wrapped: any SetupPort
    private let rules: any RulesPort
    private let cadences: [Capability: Cadence]

    init(wrapped: any SetupPort, rules: any RulesPort, cadences: [Capability: Cadence]) {
        self.wrapped = wrapped
        self.rules = rules
        self.cadences = cadences
    }

    var inlets: [Inlet] { wrapped.inlets }

    var offers: [Offer] { wrapped.offers }

    func add(_ offer: Offer, input: Input) async throws(SetupFailure) -> Inlet {
        let known = Set(wrapped.inlets.map(\.id))
        let inlet = try await wrapped.add(offer, input: input)
        guard !known.contains(inlet.id) else { return inlet }
        for capability in inlet.capabilities {
            if let preset = cadences[capability] { rules.setCadence(inlet.id, capability, preset) }
        }
        return inlet
    }

    func probe(_ inlet: Inlet.ID) async throws(SetupFailure) -> ProbeResult {
        try await wrapped.probe(inlet)
    }

    func remove(_ inlet: Inlet.ID) async throws {
        try await wrapped.remove(inlet)
    }

    func revoke(_ inlet: Inlet.ID) async throws {
        try await wrapped.revoke(inlet)
    }

    func report(for inlet: Inlet.ID) -> [ReportEntry] { wrapped.report(for: inlet) }

    func heldSlots(of inlet: Inlet.ID) -> Set<String> { wrapped.heldSlots(of: inlet) }
}
