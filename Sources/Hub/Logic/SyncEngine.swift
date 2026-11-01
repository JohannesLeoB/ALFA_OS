import Foundation

enum SyncEngine {
    enum Resolution {
        case restore
        case fail
    }

    static func key(_ inlet: Inlet.ID, _ capability: Capability) -> String {
        inlet + "|" + capability.rawValue
    }

    static func isRunning<Keys: Sequence>(_ inlet: Inlet.ID, in running: Keys) -> Bool where Keys.Element == String {
        running.contains { $0.hasPrefix(inlet + "|") }
    }

    static func resolution(capability: Capability, kind: FailureKind) -> Resolution {
        capability == .files || kind == .transient ? .restore : .fail
    }

    static func failureHint(for classification: Classification, inlet: Inlet.ID, current: InletState?) -> Hint {
        if case .failed(let existing)? = current, existing.text == Hint.signInExpiredText { return existing }
        return HintEngine.hint(classification, fixIn: .inlet(inlet))
    }

    static func kinds(of capability: Capability) -> [DataKind] {
        DataKind.allCases.filter { $0.capability == capability }
    }
}

enum ReportEngine {
    static func entry(inlet: Inlet.ID, event: ReportEvent, capability: Capability?, ok: Bool, at: Date,
                      kind: FailureKind? = nil, hint: String? = nil, original: Original? = nil) -> ReportEntry {
        ReportEntry(inlet: inlet, event: event, capability: capability, at: at, ok: ok, kind: kind, hint: hint, original: original)
    }

    static func failureEntry(inlet: Inlet.ID, event: ReportEvent, capability: Capability?, hint: Hint, at: Date) -> ReportEntry {
        entry(inlet: inlet, event: event, capability: capability, ok: false, at: at, kind: hint.kind ?? .rejected, hint: hint.text,
              original: hint.original ?? hint.detail.map { Original(provider: "unknown", text: $0) })
    }

    static func repeatsSuccess(ok: Bool, event: ReportEvent, capability: Capability?, in entries: [ReportEntry]) -> Bool {
        guard ok else { return false }
        return entries.first { $0.event == event && $0.capability == capability }?.ok == true
    }

    static func appended(_ entry: ReportEntry, to entries: [ReportEntry], limit: Int) -> [ReportEntry] {
        Array(([entry] + entries).prefix(limit))
    }
}

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
                note = probed == .distantPast ? nil : .checked(probed)
            case .connecting:
                note = .signingIn
            case .working:
                note = info.areas.lazy.compactMap { area -> LinkNote? in
                    guard let capability = area.capability, lead.capabilities.contains(capability),
                          let progress = rules.progress(lead.id, capability) else { return nil }
                    return .working(areaKey: info.areaKey(area), done: progress.done, total: progress.total)
                }.first
            case .failed(let reason):
                hint = reason
                let entries = setup.report(for: lead.id)
                note = .failed(at: entries.first { !$0.ok }?.at, lastOK: entries.first { $0.ok }?.at)
            default:
                break
            }
        }
        var areas: [AreaReading] = []
        let running = Set(rules.queue.map { SyncEngine.key($0.inlet, $0.capability) })
        for inlet in inlets {
            for area in info.areas {
                guard let capability = area.capability, inlet.capabilities.contains(capability) else { continue }
                areas.append(AreaReading(
                    area: area, inlet: inlet.id, account: inlet.account, capability: capability,
                    choice: CadenceChoice(rules.cadence(inlet.id, capability)) ?? .manual,
                    lastSync: rules.lastSync(inlet.id, capability),
                    running: running.contains(SyncEngine.key(inlet.id, capability))))
            }
        }
        return IntegrationReading(info: info, state: state, note: note, hint: hint, inlets: inlets, offers: offers, areas: areas,
                                  heldSlots: inlets.first.map { setup.heldSlots(of: $0.id) } ?? [])
    }

    @MainActor
    public static func readAll(_ catalog: any IntegrationCatalogPort, setup: any SetupPort, rules: any RulesPort) -> [IntegrationReading] {
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
            if !field.secret { values.text[field.id] = value }
        }
        return values
    }
}

enum ContactMergeEngine {
    static func merge(_ lists: [[ContactPerson]]) -> [ContactPerson] {
        var merged: [ContactPerson] = []
        var index: [String: Int] = [:]
        for person in lists.joined() {
            let key = person.address.trimmingCharacters(in: .whitespaces).lowercased()
            guard !key.isEmpty else { continue }
            if let at = index[key] {
                if merged[at].name.isEmpty, !person.name.isEmpty { merged[at] = ContactPerson(name: person.name, address: merged[at].address) }
            } else {
                index[key] = merged.count
                merged.append(person)
            }
        }
        return merged
    }
}
