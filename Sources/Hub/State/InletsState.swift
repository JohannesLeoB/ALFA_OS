import Core
import Foundation
import Observation

@MainActor @Observable
final class InletsState: RulesPort {
    static let cadencePrefix = "cadence|"
    static let lastSyncPrefix = "lastsync|"

    var records: [Inlet] = []
    var queue: [SyncJob] = []
    var reports: [Inlet.ID: [ReportEntry]] = [:]
    var syncedAt: [String: Date] = [:]

    @ObservationIgnored let configuration: Configuration
    @ObservationIgnored let inletStore: InletStore
    @ObservationIgnored let settingStore: SettingStore
    @ObservationIgnored let router: ProviderRouter
    @ObservationIgnored let watchers: FolderChanges
    @ObservationIgnored var grants: [Inlet.ID: Grant] = [:]
    @ObservationIgnored var running: Set<String> = []
    @ObservationIgnored var feeds: [DataKind: [any StockFeedPort]] = [:]
    @ObservationIgnored var stocks: [String: AnyObject] = [:]
    @ObservationIgnored var delivered: [DataKind: [Inlet.ID: (records: [any Item], at: Date)]] = [:]
    @ObservationIgnored let broadcast = Broadcast<InletEvent>()
    @ObservationIgnored var cadences: [String: Cadence] = [:]

    init(_ configuration: Configuration, inlets: InletStore, settings: SettingStore) throws {
        self.configuration = configuration
        inletStore = inlets
        settingStore = settings
        router = ProviderRouter(configuration.providers)
        watchers = FolderChanges(firstPause: configuration.deadlines.watchPause)
        records = try inlets.load()
        reports = try inlets.loadReports()
        try loadSettings()
        configuration.cadence.attach { [weak self] inlet, capability in
            guard let self else { return SyncReport(inlet: inlet, capability: capability, result: .skipped) }
            return await self.runSync(inlet, capability)
        }
        for inlet in records where inlet.state.isConnected {
            for capability in inlet.capabilities { plan(inlet.id, capability) }
        }
    }

    func record(_ id: Inlet.ID) -> Inlet? {
        records.first { $0.id == id }
    }

    func plan(_ inlet: Inlet.ID, _ capability: Capability) {
        let value = cadence(inlet, capability)
        configuration.cadence.plan(inlet, capability, value)
        watch(inlet, capability, value)
        switch value {
        case .every, .push:
            let port = configuration.cadence
            Task { await port.trigger(inlet, capability) }
        case .off, .manual, .hook:
            break
        }
    }

    func watch(_ inletID: Inlet.ID, _ capability: Capability, _ value: Cadence) {
        let key = SyncEngine.key(inletID, capability)
        watchers.stop(key)
        switch value {
        case .every, .push: break
        case .off, .manual, .hook: return
        }
        guard let inlet = record(inletID), inlet.state.isConnected, inlet.capabilities.contains(capability) else { return }
        guard let provider = router.provider(inlet.provider), let grant = grant(for: inlet),
              let port = try? provider.adapter(ChangePort.self, for: inlet, grant, renewal: renewal(inletID)) else {
            poll(inletID, capability)
            return
        }
        let cadence = configuration.cadence
        watchers.start(key, port: port, isTransient: { provider.classify($0).kind == .transient },
                       fire: { await cadence.trigger(inletID, capability) },
                       unavailable: { [weak self] in
                           Task { @MainActor in self?.poll(inletID, capability) }
                       })
    }

    func poll(_ inletID: Inlet.ID, _ capability: Capability) {
        guard cadence(inletID, capability) == .push else { return }
        configuration.cadence.plan(inletID, capability, .every(configuration.deadlines.pushFallback))
    }

    func loadSettings() throws {
        for (key, data) in try settingStore.all() {
            let parts = key.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 3 else { continue }
            let pair = parts[1] + "|" + parts[2]
            switch parts[0] + "|" {
            case Self.cadencePrefix:
                if let value = SettingStore.decoded(data, as: Cadence.self) { cadences[pair] = value }
            case Self.lastSyncPrefix:
                if let value = SettingStore.decoded(data, as: Date.self) { syncedAt[pair] = value }
            default:
                break
            }
        }
    }

    func persist<V: Encodable>(_ key: String, _ value: V) {
        try? settingStore.store(value, forKey: key)
    }

    func emit(_ event: InletEvent) {
        broadcast.emit(event)
    }

    func update(_ id: Inlet.ID, persist: Bool, _ change: (inout Inlet) -> Void) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        change(&records[index])
        if persist { try? inletStore.save(records[index]) }
        emit(.inletChanged(id))
    }

    func log(_ inlet: Inlet.ID, _ event: ReportEvent, capability: Capability? = nil, ok: Bool) {
        if ReportEngine.repeatsSuccess(ok: ok, event: event, capability: capability, in: reports[inlet] ?? []) { return }
        store(ReportEngine.entry(inlet: inlet, event: event, capability: capability, ok: ok, at: configuration.clock()))
    }

    func logFailure(_ inlet: Inlet.ID, _ event: ReportEvent, capability: Capability? = nil, _ hint: Hint) {
        store(ReportEngine.failureEntry(inlet: inlet, event: event, capability: capability, hint: hint, at: configuration.clock()))
    }

    private func store(_ entry: ReportEntry) {
        try? inletStore.append(entry, limit: configuration.reportLimit)
        reports[entry.inlet] = ReportEngine.appended(entry, to: reports[entry.inlet] ?? [], limit: configuration.reportLimit)
    }

    func grant(for inlet: Inlet) -> Grant? {
        if let cached = grants[inlet.id] { return cached }
        guard let names = try? inletStore.slots(of: inlet.id), !names.isEmpty else { return nil }
        var values: [String: String] = [:]
        for name in names {
            guard let value = try? configuration.keychain.get(KeySlot(inlet: inlet.id, name: name)) else { return nil }
            values[name] = value
        }
        let loaded = Grant(values: values)
        grants[inlet.id] = loaded
        return loaded
    }

    func meter(_ inlet: Inlet.ID, _ capability: Capability) -> CostMeter {
        CostMeter(inlet: inlet, capability: capability, cost: configuration.cost, clock: configuration.clock)
    }

    func cadence(_ inlet: Inlet.ID, _ capability: Capability) -> Cadence {
        cadences[SyncEngine.key(inlet, capability)] ?? .manual
    }

    func setCadence(_ inlet: Inlet.ID, _ capability: Capability, _ value: Cadence) {
        let key = SyncEngine.key(inlet, capability)
        cadences[key] = value
        persist(Self.cadencePrefix + key, value)
        if record(inlet)?.state.isConnected == true {
            configuration.cadence.plan(inlet, capability, value)
        }
        watch(inlet, capability, value)
    }

    func lastSync(_ inlet: Inlet.ID, _ capability: Capability) -> Date? {
        syncedAt[SyncEngine.key(inlet, capability)]
    }

    func syncNow(_ inlet: Inlet.ID, _ capability: Capability) async {
        await configuration.cadence.trigger(inlet, capability)
    }
}
