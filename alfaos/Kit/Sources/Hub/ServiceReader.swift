import Foundation

public struct AreaReading: Identifiable, Equatable, Sendable {
    public var area: ServiceArea
    public var inlet: Inlet.ID
    public var capability: Capability
    public var choice: CadenceChoice
    public var lastSync: Date?
    public var running: Bool

    public var id: String { area.id }
}

public enum ServiceStep: Equatable, Sendable {
    case add([Offer])
    case renew(Inlet.ID)
    case check(Inlet.ID)
    case none
}

public struct ServiceReading: Identifiable, Equatable, Sendable {
    public var info: ServiceInfo
    public var state: LinkState
    public var note: LinkNote?
    public var hint: Hint?
    public var inlets: [Inlet]
    public var offers: [Offer]
    public var areas: [AreaReading]

    public var id: String { info.id }

    public var asksReconnect: Bool { state.isActive }

    public var step: ServiceStep {
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

@MainActor
public enum ServiceReader {
    public static func read(_ info: ServiceInfo, setup: any HubSetup, rules: any HubRules) -> ServiceReading {
        let inlets = setup.inlets.filter { info.providers.contains($0.provider) }
        let offers = setup.offers.filter { info.providers.contains($0.provider) } + (ServiceCatalog.offer(for: info).map { [$0] } ?? [])
        let states = inlets.map { LinkState($0.state) }
        let state = LinkState.combined(states)
        let lead = inlets.first { LinkState($0.state) == state }
        var hint: Hint?
        var note: LinkNote?
        if let lead {
            switch lead.state {
            case .connected(let probed):
                note = probed == .distantPast ? .unchecked : .checked(probed)
            case .signedIn:
                note = .unchecked
            case .connecting:
                note = .signingIn
            case .failed(let reason):
                hint = reason
                let entries = setup.report(for: lead.id)
                note = .failed(at: entries.first { !$0.ok }?.at, lastOK: entries.first { $0.ok }?.at)
            default:
                break
            }
        }
        var areas: [AreaReading] = []
        if let lead {
            let running = Set(rules.queue.map { $0.inlet + "|" + $0.capability.rawValue })
            for area in info.areas {
                guard let capability = area.capability, lead.capabilities.contains(capability) else { continue }
                areas.append(AreaReading(
                    area: area, inlet: lead.id, capability: capability,
                    choice: CadenceChoice(rules.cadence(lead.id, capability)) ?? .manual,
                    lastSync: rules.lastSync(lead.id, capability),
                    running: running.contains(lead.id + "|" + capability.rawValue)))
            }
        }
        return ServiceReading(info: info, state: state, note: note, hint: hint, inlets: inlets, offers: offers, areas: areas)
    }

    public static func readAll(setup: any HubSetup, rules: any HubRules) -> [ServiceReading] {
        ServiceCatalog.all.map { read($0, setup: setup, rules: rules) }
    }

    public static func badCount(_ readings: [ServiceReading]) -> Int {
        readings.filter { $0.state.isBad }.count
    }
}

public struct ServiceValues: Equatable, Sendable {
    public var text: [String: String]
    public var held: Set<String>

    public static let none = ServiceValues(text: [:], held: [])

    public static func read(_ reading: ServiceReading, keychain: any KeychainPort) -> ServiceValues {
        guard let inlet = reading.inlets.first else { return .none }
        var values = ServiceValues.none
        for field in reading.info.fields {
            guard let value = try? keychain.get(KeySlot(inlet: inlet.id, name: field.id)), !value.isEmpty else { continue }
            values.held.insert(field.id)
            if !field.secret { values.text[field.id] = value }
        }
        return values
    }
}
