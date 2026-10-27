import Foundation

public struct IntegrationReading: Identifiable, Equatable, Sendable {
    public var info: IntegrationInfo
    public var state: LinkState
    public var note: LinkNote?
    public var hint: Hint?
    public var inlets: [Inlet]
    public var offers: [Offer]
    public var areas: [AreaReading]

    public var id: String { info.id }

    public var asksReconnect: Bool { state.isActive }

    public var step: IntegrationStep {
        let lead = inlets.first { LinkState($0.state) == state } ?? inlets.first
        switch state {
        case .connected, .stored, .working:
            return lead.map { .check($0.id) } ?? .none
        case .failed, .unreadable:
            return lead.map { .renew($0.id) } ?? .none
        case .notConnected, .orphaned:
            return offers.isEmpty ? .none : .add(offers)
        case .connecting:
            return .none
        }
    }
}

public enum IntegrationStep: Equatable, Sendable {
    case add([Offer])
    case renew(Inlet.ID)
    case check(Inlet.ID)
    case none
}

public struct AreaReading: Identifiable, Equatable, Sendable {
    public var area: IntegrationArea
    public var inlet: Inlet.ID
    public var capability: Capability
    public var choice: CadenceChoice
    public var lastSync: Date?
    public var running: Bool

    public var id: String { area.id }
}
