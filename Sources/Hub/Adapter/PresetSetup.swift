@MainActor
final class PresetSetup: SetupPort {
    private let wrapped: any SetupPort
    private let rules: any RulesPort
    private let cadences: [Capability: Duration]

    init(wrapped: any SetupPort, rules: any RulesPort, cadences: [Capability: Duration]) {
        self.wrapped = wrapped
        self.rules = rules
        self.cadences = cadences
    }

    var inlets: [Inlet] { wrapped.inlets }

    var offers: [Offer] { wrapped.offers }

    func add(_ offer: Offer, input: Input) async throws(SetupFailure) -> Inlet {
        let inlet = try await wrapped.add(offer, input: input)
        for capability in inlet.capabilities {
            if let interval = cadences[capability] { rules.setCadence(inlet.id, capability, .every(interval)) }
        }
        return inlet
    }

    func probe(_ inlet: Inlet.ID) async throws(SetupFailure) -> ProbeResult {
        try await wrapped.probe(inlet)
    }

    func remove(_ inlet: Inlet.ID) async throws {
        try await wrapped.remove(inlet)
    }

    func report(for inlet: Inlet.ID) -> [ReportEntry] { wrapped.report(for: inlet) }
}
