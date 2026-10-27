import Foundation

public enum IntegrationReadEngine {
    @MainActor
    public static func read(_ info: IntegrationInfo, setup: any SetupPort, rules: any RulesPort) -> IntegrationReading {
        let inlets = setup.inlets.filter { info.providers.contains($0.provider) }
        let offers = setup.offers.filter { info.providers.contains($0.provider) }
        let state = LinkState.combined(inlets.map { LinkState($0.state) })
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
            let running = Set(rules.queue.map { SyncEngine.key($0.inlet, $0.capability) })
            for area in info.areas {
                guard let capability = area.capability, lead.capabilities.contains(capability) else { continue }
                areas.append(AreaReading(
                    area: area, inlet: lead.id, capability: capability,
                    choice: CadenceChoice(rules.cadence(lead.id, capability)) ?? .manual,
                    lastSync: rules.lastSync(lead.id, capability),
                    running: running.contains(SyncEngine.key(lead.id, capability))))
            }
        }
        return IntegrationReading(info: info, state: state, note: note, hint: hint, inlets: inlets, offers: offers, areas: areas)
    }

    @MainActor
    public static func readAll(_ catalog: IntegrationCatalogStore, setup: any SetupPort, rules: any RulesPort) -> [IntegrationReading] {
        catalog.entries.map { read($0, setup: setup, rules: rules) }
    }

    public static func badCount(_ readings: [IntegrationReading]) -> Int {
        readings.filter { $0.state.isBad }.count
    }

    public static func failedCount(_ readings: [IntegrationReading]) -> Int {
        readings.filter { $0.state == .failed }.count
    }

    public static func values(of reading: IntegrationReading, keychain: any KeychainPort) -> IntegrationValues {
        guard let inlet = reading.inlets.first else { return .none }
        var values = IntegrationValues.none
        for field in reading.info.fields {
            guard let value = try? keychain.get(KeySlot(inlet: inlet.id, name: field.id)), !value.isEmpty else { continue }
            values.held.insert(field.id)
            if !field.secret { values.text[field.id] = value }
        }
        return values
    }
}
