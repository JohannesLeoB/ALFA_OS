import Foundation

extension InletState {
    public var probed: Date? {
        if case .connected(let date) = self { date } else { nil }
    }

    public var hint: Hint? {
        if case .failed(let hint) = self { hint } else { nil }
    }

    public var canRenew: Bool {
        switch self {
        case .failed, .keychainUnreadable: true
        default: false
        }
    }
}

extension Hint {
    public static func failed(_ error: Error) -> Hint {
        Hint(text: "hint.provider.failed", detail: String(describing: error))
    }
}

public struct Renewal: Equatable, Sendable {
    public var offer: Offer
    public var values: [Field.ID: String]
}

extension HubSetup {
    public func renewal(of id: Inlet.ID) -> Renewal? {
        guard let inlet = inlets.first(where: { $0.id == id }), inlet.state.canRenew else { return nil }
        let matching = offers.filter { $0.provider == inlet.provider }
        guard let offer = matching.first(where: { $0.title == inlet.title }) ?? matching.first else { return nil }
        var values = offer.preset?.values ?? [:]
        if case .form(let fields) = offer.way, fields.contains(where: { $0.id == IMAPField.address }) {
            values[IMAPField.address] = inlet.account
        }
        return Renewal(offer: offer, values: values)
    }
}
