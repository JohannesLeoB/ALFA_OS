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
    var progresses: [String: RunProgress] = [:]

    @ObservationIgnored let configuration: Configuration
    @ObservationIgnored let inletStore: InletStore
    @ObservationIgnored let settingStore: SettingStore
    @ObservationIgnored let router: ProviderRouter
    @ObservationIgnored let watchers: FolderChanges
    @ObservationIgnored var grants: [Inlet.ID: Grant] = [:]
    @ObservationIgnored var running: Set<String> = []
    @ObservationIgnored var tracking: [String: Int] = [:]
    @ObservationIgnored var resting: [Inlet.ID: InletState] = [:]
    @ObservationIgnored var probes: Set<Inlet.ID> = []
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

    func progress(_ inlet: Inlet.ID, _ capability: Capability) -> RunProgress? {
        progresses[SyncEngine.key(inlet, capability)]
    }

    func lastSync(_ inlet: Inlet.ID, _ capability: Capability) -> Date? {
        syncedAt[SyncEngine.key(inlet, capability)]
    }

    @discardableResult
    func syncNow(_ inlet: Inlet.ID, _ capability: Capability) async -> SyncReport {
        await configuration.cadence.trigger(inlet, capability)
    }
}

enum Persist {
    case never
    case changed
    case always
}

extension InletsState {
    func restingState(_ id: Inlet.ID) -> InletState? {
        if let held = resting[id] { return held }
        return record(id).map { InletStore.durable($0.state) }
    }

    func isWorking(_ id: Inlet.ID) -> Bool {
        SyncEngine.isRunning(id, in: running) || SyncEngine.isRunning(id, in: tracking.keys)
    }

    func isBusy(_ id: Inlet.ID) -> Bool {
        probes.contains(id) || isWorking(id)
    }

    func begin(_ id: Inlet.ID) {
        if resting[id] == nil { resting[id] = restingState(id) }
        show(id)
    }

    func end(_ id: Inlet.ID) {
        show(id)
        if !isBusy(id) { resting[id] = nil }
    }

    func rest(_ id: Inlet.ID, as state: InletState, persist: Persist) {
        guard record(id) != nil else { return }
        let target = state.isTransient ? InletStore.durable(state) : state
        let before = restingState(id)
        resting[id] = target
        if target.isStorable {
            switch persist {
            case .never: break
            case .always: save(id, target)
            case .changed: if before.map({ !$0.sameKind(as: target) }) ?? true { save(id, target) }
            }
        }
        end(id)
    }

    func probed(_ id: Inlet.ID, at now: Date) {
        guard case .connected? = resting[id] else { return }
        rest(id, as: .connected(probed: now), persist: .changed)
    }

    func beginProbe(_ id: Inlet.ID) {
        probes.insert(id)
        begin(id)
    }

    func endProbe(_ id: Inlet.ID, as state: InletState? = nil, persist: Persist = .never) {
        guard probes.remove(id) != nil else { return }
        if let state { rest(id, as: state, persist: persist) } else { end(id) }
    }

    func forget(_ id: Inlet.ID) {
        resting[id] = nil
        probes.remove(id)
    }

    private func show(_ id: Inlet.ID) {
        guard let base = restingState(id) else { return }
        let shown: InletState
        switch base {
        case _ where probes.contains(id): shown = .connecting
        case .failed, .keychainUnreadable: shown = base
        case _ where isWorking(id): shown = .working
        default: shown = base
        }
        update(id, persist: false) { $0.state = shown }
    }

    private func save(_ id: Inlet.ID, _ state: InletState) {
        guard var inlet = record(id) else { return }
        inlet.state = state
        try? inletStore.save(inlet)
    }
}

extension InletsState: AccessPort {
    var events: AsyncStream<InletEvent> { broadcast.stream }

    func stock<T: Item>(_ kind: DataKind, as type: T.Type) -> StockState<T> {
        let key = kind.rawValue + "|" + String(describing: ObjectIdentifier(T.self))
        if let existing = stocks[key] as? StockState<T> { return existing }
        let made = StockState<T> { [weak self] in await self?.refresh(kind) }
        stocks[key] = made
        feeds[kind, default: []].append(made)
        for (inlet, last) in delivered[kind] ?? [:] { made.apply(inlet: inlet, records: last.records, at: last.at) }
        return made
    }

    func refresh(_ kind: DataKind) async {
        guard let capability = kind.capability else { return }
        let targets = records.filter { $0.state.isConnected && $0.capabilities.contains(capability) }
        guard !targets.isEmpty else { return }
        let kindFeeds = feeds[kind] ?? []
        kindFeeds.forEach { $0.begin() }
        for inlet in targets { _ = await runSync(inlet.id, capability) }
        kindFeeds.forEach { $0.end() }
    }

    func inlets(for capability: Capability) -> [Inlet] {
        records.filter { $0.state.isConnected && $0.capabilities.contains(capability) }
    }

    func configured(for capability: Capability) -> [Inlet] {
        records.filter { $0.capabilities.contains(capability) }
    }

    func port<P>(_ port: P.Type, for inletID: Inlet.ID) throws(HubFailure) -> P {
        guard let inlet = record(inletID), inlet.state.isConnected else { throw .notConnected(inletID) }
        guard let spec = configuration.catalog.spec(for: port) else {
            throw .provider(Hint(text: HintEngine.unknownPortText, detail: String(describing: port)))
        }
        guard inlet.capabilities.contains(spec.capability) else { throw .capabilityMissing(inletID, spec.capability) }
        guard let provider = router.provider(inlet.provider) else { throw .notConnected(inletID) }
        guard let grant = grant(for: inlet) else {
            rest(inletID, as: .keychainUnreadable, persist: .never)
            throw .notConnected(inletID)
        }
        do {
            guard let made = try spec.make(provider, inlet, grant, meter(inletID, spec.capability), renewal(inletID)) as? P else {
                throw HubFailure.capabilityMissing(inletID, spec.capability)
            }
            return made
        } catch let error as HubFailure {
            throw error
        } catch {
            throw .provider(HintEngine.hint(classify(error, inlet: inletID)))
        }
    }

    func classify(_ error: any Error, inlet: Inlet.ID) -> Classification {
        router.classify(error, provider: record(inlet)?.provider)
    }

    func runSync(_ inletID: Inlet.ID, _ capability: Capability) async -> SyncReport {
        let key = SyncEngine.key(inletID, capability)
        guard let inlet = record(inletID), inlet.state.isConnected, inlet.capabilities.contains(capability),
              !running.contains(key), let provider = router.provider(inlet.provider),
              let spec = configuration.catalog.spec(for: capability), let grant = grant(for: inlet) else {
            return SyncReport(inlet: inletID, capability: capability, result: .skipped)
        }
        running.insert(key)
        let job = SyncJob(inlet: inletID, capability: capability, startedAt: configuration.clock())
        queue.append(job)
        begin(inletID)
        defer {
            running.remove(key)
            if tracking[key] == nil { progresses[key] = nil }
            queue.removeAll { $0 == job }
            end(inletID)
        }
        do {
            let outcome = try await spec.run(provider, inlet, grant, meter(inletID, capability), renewal(inletID), reporter(key))
            let now = configuration.clock()
            if record(inletID) != nil {
                for (kind, items) in outcome.deliveries {
                    delivered[kind, default: [:]][inletID] = (items, now)
                    for feed in feeds[kind] ?? [] { feed.apply(inlet: inletID, records: items, at: now) }
                    emit(.newItems(kind))
                }
                probed(inletID, at: now)
            }
            log(inletID, .sync, capability: capability, ok: true)
            syncedAt[key] = now
            persist(Self.lastSyncPrefix + key, now)
            emit(.syncFinished(capability, inletID))
            return SyncReport(inlet: inletID, capability: capability, result: .finished(items: outcome.count))
        } catch {
            if error is CancellationError {
                return SyncReport(inlet: inletID, capability: capability, result: .skipped)
            }
            let classification = classify(error, inlet: inletID)
            let failure = SyncEngine.failureHint(for: classification, inlet: inletID, current: record(inletID)?.state)
            for kind in SyncEngine.kinds(of: capability) {
                for feed in feeds[kind] ?? [] { feed.disturb(failure) }
            }
            logFailure(inletID, .sync, capability: capability, failure)
            switch SyncEngine.resolution(capability: capability, kind: classification.kind) {
            case .restore:
                break
            case .fail:
                rest(inletID, as: .failed(failure), persist: .changed)
            }
            emit(.syncFailed(capability, inletID, failure))
            return SyncReport(inlet: inletID, capability: capability, result: .failed(failure))
        }
    }

    func track<T>(_ inlet: Inlet.ID, _ capability: Capability, body: @MainActor (SyncReporter) async -> T) async -> T {
        let key = SyncEngine.key(inlet, capability)
        tracking[key, default: 0] += 1
        begin(inlet)
        defer {
            let left = (tracking[key] ?? 1) - 1
            tracking[key] = left > 0 ? left : nil
            if left <= 0, !running.contains(key) { progresses[key] = nil }
            end(inlet)
        }
        return await body(reporter(key))
    }

    private func reporter(_ key: String) -> SyncReporter {
        SyncReporter { [weak self] progress in
            Task { @MainActor in
                guard let self, self.running.contains(key) || self.tracking[key] != nil else { return }
                self.progresses[key] = progress
            }
        }
    }

    func renewal(_ inletID: Inlet.ID) -> GrantRenewal {
        GrantRenewal(
            renewed: { [weak self] grant in
                Task { @MainActor in self?.adopt(grant, for: inletID) }
            },
            failed: { [weak self] error in
                Task { @MainActor in self?.expire(inletID, error) }
            }
        )
    }

    private func adopt(_ grant: Grant, for inletID: Inlet.ID) {
        guard let inlet = record(inletID) else { return }
        grants[inletID] = grant
        do {
            for (name, value) in SetupEngine.sorted(grant) {
                try configuration.keychain.put(value, at: KeySlot(inlet: inletID, name: name))
            }
            try inletStore.save(inlet, slots: SetupEngine.sorted(grant).map(\.key))
            log(inletID, .renewal, ok: true)
            emit(.inletChanged(inletID))
            for capability in inlet.capabilities { watch(inletID, capability, cadence(inletID, capability)) }
        } catch {
            let failure = Hint(text: HintEngine.unwritableText, detail: String(describing: error), fixIn: .inlet(inletID))
            rest(inletID, as: .failed(failure), persist: .changed)
        }
    }

    private func expire(_ inletID: Inlet.ID, _ error: any Error) {
        guard record(inletID) != nil else { return }
        let failure = HintEngine.hint(Classification(kind: .signIn, original: classify(error, inlet: inletID).original),
                                      fixIn: .inlet(inletID))
        logFailure(inletID, .renewal, failure)
        rest(inletID, as: .failed(failure), persist: .changed)
    }
}

@MainActor @Observable
public final class StockState<T: Item>: StockFeedPort {
    public private(set) var items: [T] = []
    public private(set) var phase: StockPhase = .empty

    @ObservationIgnored private var refresher: (@MainActor () async -> Void)?
    @ObservationIgnored private var before: StockPhase?

    public init(refresher: @escaping @MainActor () async -> Void) {
        self.refresher = refresher
    }

    public func refresh() async {
        await refresher?()
    }

    func begin() {
        before = phase
        phase = .loading
    }

    func end() {
        if phase == .loading, let before { phase = before }
        before = nil
    }

    public func apply(inlet: Inlet.ID, records: [any Item], at: Date) {
        items = items.filter { $0.inlet != inlet } + records.compactMap { $0 as? T }
        phase = .current(since: at)
    }

    func drop(inlet: Inlet.ID) {
        items = items.filter { $0.inlet != inlet }
        if items.isEmpty, case .current = phase { phase = .empty }
    }

    func disturb(_ hint: Hint) {
        phase = .disturbed(hint)
    }
}

public enum StockPhase: Equatable, Sendable {
    case empty
    case loading
    case current(since: Date)
    case disturbed(Hint)
}
