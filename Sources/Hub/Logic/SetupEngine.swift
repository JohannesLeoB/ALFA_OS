import Foundation

enum SetupEngine {
    static func newInlet(id: String, offer: Offer) -> Inlet {
        Inlet(id: id, provider: offer.provider, capabilities: offer.capabilities, owner: offer.owner, title: offer.title)
    }

    static func existing(offer: Offer, account: String, in inlets: [Inlet]) -> Inlet? {
        let address = normalized(account)
        return inlets.first { inlet in
            guard normalized(inlet.account) == address else { return false }
            if offer.capabilities.contains(.mail), inlet.capabilities.contains(.mail) { return true }
            return inlet.provider == offer.provider
        }
    }

    static func normalized(_ account: String) -> String {
        account.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func differs(_ expected: String, from account: String) -> Bool {
        let wanted = normalized(expected)
        return !wanted.isEmpty && wanted != normalized(account)
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
        if inlet.capabilities.contains(.mail), !inlet.account.isEmpty { values[Input.expectedAccountKey] = inlet.account }
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
