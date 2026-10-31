import Foundation

public struct IntegrationReading: Identifiable, Equatable, Sendable {
    public var info: IntegrationInfo
    public var state: LinkState
    public var note: LinkNote?
    public var hint: Hint?
    public var inlets: [Inlet]
    public var offers: [Offer]
    public var areas: [AreaReading]
    public var heldSlots: Set<String> = []

    public var id: String { info.id }

    public var asksReconnect: Bool { state.isActive }

    public var lead: Inlet? { inlets.first { LinkState($0.state) == state } ?? inlets.first }

    public var leadAddress: String? {
        guard let lead, lead.capabilities.contains(.mail), !lead.account.isEmpty else { return nil }
        return lead.account
    }

    public var step: IntegrationStep {
        let lead = lead
        switch state {
        case .connected, .working, .failed, .unreadable:
            return lead.map { .renew($0.id) } ?? .none
        case .notConnected:
            return offers.isEmpty ? .none : .add(offers)
        case .connecting:
            return .none
        }
    }
}

public enum IntegrationStep: Equatable, Sendable {
    case add([Offer])
    case renew(Inlet.ID)
    case none
}

public struct AreaReading: Identifiable, Equatable, Sendable {
    public var area: IntegrationArea
    public var inlet: Inlet.ID
    public var account: String
    public var capability: Capability
    public var choice: CadenceChoice
    public var lastSync: Date?
    public var running: Bool

    public var id: String { inlet + "|" + area.id }
}
