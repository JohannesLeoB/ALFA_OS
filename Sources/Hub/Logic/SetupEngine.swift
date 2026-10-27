enum SetupEngine {
    static func newInlet(id: String, offer: Offer) -> Inlet {
        Inlet(id: id, provider: offer.provider, capabilities: offer.capabilities, owner: offer.owner, title: offer.title)
    }

    static func checkLimits(_ offer: Offer, inlets: [Inlet], company: CompanySetup) throws(SetupFailure) {
        for capability in offer.capabilities {
            let maximum = company.limit(capability)
            let used = inlets.filter { $0.owner == offer.owner && $0.capabilities.contains(capability) }.count
            if used >= maximum { throw .limitReached(capability, max: maximum) }
        }
    }

    static func existing(provider: String, account: String, in inlets: [Inlet]) -> Inlet? {
        inlets.first { $0.provider == provider && $0.account == account }
    }

    static func sorted(_ grant: Grant) -> [(key: String, value: String)] {
        grant.values.sorted { $0.key < $1.key }
    }

    static func keychainFailure(_ error: any Error) -> SetupFailure {
        if case KeychainFailure.status(let status) = error { return .keychain(status) }
        return .keychain(-1)
    }
}

enum RenewalEngine {
    static func renewal(of id: Inlet.ID, inlets: [Inlet], offers: [Offer]) -> Renewal? {
        guard let inlet = inlets.first(where: { $0.id == id }), inlet.state.canRenew else { return nil }
        let matching = offers.filter { $0.provider == inlet.provider }
        guard let offer = matching.first(where: { $0.title == inlet.title }) ?? matching.first else { return nil }
        var values = offer.preset?.values ?? [:]
        if case .form(let fields) = offer.way {
            for field in fields where field.holdsAccount { values[field.id] = inlet.account }
        }
        return Renewal(offer: offer, values: values)
    }
}

public enum SignOutEngine {
    @MainActor
    public static func run(setup: any SetupPort) async -> [Inlet.ID] {
        var failed: [Inlet.ID] = []
        for inlet in setup.inlets {
            do { try await setup.remove(inlet.id) } catch { failed.append(inlet.id) }
        }
        return failed
    }
}
