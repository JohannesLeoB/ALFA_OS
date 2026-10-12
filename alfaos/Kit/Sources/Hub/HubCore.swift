import Foundation
import Observation

@MainActor @Observable
final class HubCore: HubAccess, HubSetup, HubRules {
    private(set) var inlets: [Inlet] = []
    private(set) var queue: [SyncJob] = []

    @ObservationIgnored private let config: HubConfiguration
    @ObservationIgnored private let store: Store
    @ObservationIgnored private var providers: [String: any Provider] = [:]
    @ObservationIgnored private var grants: [Inlet.ID: Grant] = [:]
    @ObservationIgnored private var running: Set<String> = []
    @ObservationIgnored private var feeds: [DataKind: [any StockFeed]] = [:]
    @ObservationIgnored private var stocks: [String: AnyObject] = [:]
    @ObservationIgnored private var delivered: [DataKind: [Inlet.ID: (records: [any Record], at: Date)]] = [:]
    @ObservationIgnored private var listeners: [UUID: AsyncStream<HubEvent>.Continuation] = [:]
    @ObservationIgnored private var cadences: [String: Cadence] = [:]
    @ObservationIgnored private var truths: [DataKind: Inlet.ID] = [:]
    @ObservationIgnored private var limits: [Capability: Int]
    @ObservationIgnored private var roles: [Person.ID: Role] = [:]
    @ObservationIgnored private var locks: [String: LockRule] = [:]

    init(_ config: HubConfiguration) throws {
        self.config = config
        self.store = try Store(config.database)
        self.limits = config.company.limits
        for provider in config.providers { providers[provider.id] = provider }
        inlets = try store.loadInlets()
        try loadSettings()
        config.cadence.attach { [weak self] inlet, capability in
            guard let self else { return SyncReport(inlet: inlet, capability: capability, result: .skipped) }
            return await self.runSync(inlet, capability)
        }
        for inlet in inlets where inlet.state.isConnected {
            for capability in inlet.capabilities {
                config.cadence.plan(inlet.id, capability, cadence(inlet.id, capability))
            }
        }
    }

    private func loadSettings() throws {
        let decoder = JSONDecoder()
        for (key, data) in try store.loadSettings() {
            let parts = key.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            switch parts.first {
            case "cadence" where parts.count == 3:
                cadences[parts[1] + "|" + parts[2]] = try decoder.decode(Cadence.self, from: data)
            case "truth" where parts.count == 2:
                if let kind = DataKind(rawValue: parts[1]) { truths[kind] = try decoder.decode(String.self, from: data) }
            case "limit" where parts.count == 2:
                if let capability = Capability(rawValue: parts[1]) { limits[capability] = try decoder.decode(Int.self, from: data) }
            case "role" where parts.count == 2:
                roles[parts[1]] = try decoder.decode(Role.self, from: data)
            case "lock" where parts.count == 3:
                locks[parts[1] + "|" + parts[2]] = try decoder.decode(LockRule.self, from: data)
            default:
                break
            }
        }
    }

    private func persist<V: Encodable>(_ key: String, _ value: V) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? store.putSetting(key, data)
    }

    private func emit(_ event: HubEvent) {
        for continuation in listeners.values { continuation.yield(event) }
    }

    private func hint(_ error: Error, fixIn: SettingsTarget? = nil) -> Hint {
        Hint(text: "hint.provider.failed", detail: String(describing: error), fixIn: fixIn)
    }

    private func update(_ id: Inlet.ID, persist: Bool, _ change: (inout Inlet) -> Void) {
        guard let index = inlets.firstIndex(where: { $0.id == id }) else { return }
        change(&inlets[index])
        if persist { try? store.save(inlets[index]) }
        emit(.inletChanged(id))
    }

    var events: AsyncStream<HubEvent> {
        let (stream, continuation) = AsyncStream<HubEvent>.makeStream()
        let id = UUID()
        listeners[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.listeners[id] = nil }
        }
        return stream
    }

    func stock<T: Record>(_ kind: DataKind, as type: T.Type) -> Stock<T> {
        let key = kind.rawValue + "|" + String(describing: ObjectIdentifier(T.self))
        if let existing = stocks[key] as? Stock<T> { return existing }
        let made = Stock<T> { [weak self] in await self?.refresh(kind) }
        stocks[key] = made
        feeds[kind, default: []].append(made)
        for (inlet, last) in delivered[kind] ?? [:] { made.apply(inlet: inlet, records: last.records, at: last.at) }
        return made
    }

    private func refresh(_ kind: DataKind) async {
        guard let capability = kind.capability else { return }
        let targets = inlets.filter { $0.state.isConnected && $0.capabilities.contains(capability) }
        guard !targets.isEmpty else { return }
        let kindFeeds = feeds[kind] ?? []
        kindFeeds.forEach { $0.begin() }
        for inlet in targets { _ = await runSync(inlet.id, capability) }
        kindFeeds.forEach { $0.end() }
    }

    func inlets(for capability: Capability) -> [Inlet] {
        inlets.filter { $0.state.isConnected && $0.capabilities.contains(capability) }
    }

    private func grant(for inlet: Inlet) -> Grant? {
        if let cached = grants[inlet.id] { return cached }
        guard let names = try? store.slots(of: inlet.id), !names.isEmpty else { return nil }
        var values: [String: String] = [:]
        for name in names {
            guard let value = try? config.keychain.get(KeySlot(inlet: inlet.id, name: name)) else { return nil }
            values[name] = value
        }
        let loaded = Grant(values: values)
        grants[inlet.id] = loaded
        return loaded
    }

    private func meter(_ inlet: Inlet.ID, _ capability: Capability) -> CostMeter {
        CostMeter(inlet: inlet, capability: capability, cost: config.cost, clock: config.clock)
    }

    func port<P>(_ port: P.Type, for inletID: Inlet.ID) throws(HubError) -> P {
        try resolve(port, for: inletID, checkingRead: true)
    }

    func resolve<P>(_ port: P.Type, for inletID: Inlet.ID, checkingRead: Bool) throws(HubError) -> P {
        guard let inlet = inlets.first(where: { $0.id == inletID }), inlet.state.isConnected else {
            throw .notConnected(inletID)
        }
        guard let spec = config.catalog.spec(for: port) else {
            throw .provider(Hint(text: "hint.port.unknown", detail: String(describing: port)))
        }
        guard inlet.capabilities.contains(spec.capability) else {
            throw .capabilityMissing(inletID, spec.capability)
        }
        if checkingRead, !may(config.person.id, .read(spec.capability)) { throw .noRight(.read(spec.capability)) }
        guard let provider = providers[inlet.provider] else { throw .notConnected(inletID) }
        guard let grant = grant(for: inlet) else {
            update(inletID, persist: false) { $0.state = .keychainUnreadable }
            throw .notConnected(inletID)
        }
        do {
            guard let made = try spec.make(provider, inlet, grant, meter(inletID, spec.capability)) as? P else {
                throw HubError.capabilityMissing(inletID, spec.capability)
            }
            return made
        } catch let error as HubError {
            throw error
        } catch {
            throw .provider(hint(error))
        }
    }

    func write(_ order: WriteOrder) async throws(HubError) {
        guard let inlet = inlets.first(where: { $0.id == order.inlet }), inlet.state.isConnected else {
            throw .notConnected(order.inlet)
        }
        guard may(config.person.id, order.right) else { throw .noRight(order.right) }
        switch locks[order.inlet + "|" + order.right.rawValue] ?? .open {
        case .open:
            break
        case .blocked:
            throw .blocked(.locked(order.right))
        case .approval, .fourEyes:
            emit(.approvalPending(order.inlet, order.right))
            throw .blocked(.approvalRequired(order.right))
        }
        do {
            try await order.run(WriteContext(core: self), order.inlet)
        } catch let error as HubError {
            throw error
        } catch {
            throw .provider(hint(error))
        }
    }

    func runSync(_ inletID: Inlet.ID, _ capability: Capability) async -> SyncReport {
        let key = inletID + "|" + capability.rawValue
        guard let inlet = inlets.first(where: { $0.id == inletID }), inlet.state.isConnected,
              inlet.capabilities.contains(capability), !running.contains(key),
              let provider = providers[inlet.provider], let spec = config.catalog.spec(for: capability),
              let grant = grant(for: inlet) else {
            return SyncReport(inlet: inletID, capability: capability, result: .skipped)
        }
        running.insert(key)
        let job = SyncJob(inlet: inletID, capability: capability, startedAt: config.clock())
        queue.append(job)
        let previous = inlet.state
        update(inletID, persist: false) { $0.state = .working }
        defer {
            running.remove(key)
            queue.removeAll { $0 == job }
        }
        do {
            let outcome = try await spec.run(provider, inlet, grant, meter(inletID, capability))
            let now = config.clock()
            if inlets.contains(where: { $0.id == inletID }) {
                for (kind, records) in outcome.deliveries {
                    delivered[kind, default: [:]][inletID] = (records, now)
                    for feed in feeds[kind] ?? [] { feed.apply(inlet: inletID, records: records, at: now) }
                    emit(.newItems(kind))
                }
                update(inletID, persist: false) { $0.state = previous }
            }
            emit(.syncFinished(capability, inletID))
            return SyncReport(inlet: inletID, capability: capability, result: .finished(items: outcome.count))
        } catch {
            let failure = hint(error, fixIn: .inlet(inletID))
            for kind in DataKind.allCases where kind.capability == capability {
                for feed in feeds[kind] ?? [] { feed.disturb(failure) }
            }
            update(inletID, persist: true) { $0.state = .failed(failure) }
            emit(.syncFinished(capability, inletID))
            return SyncReport(inlet: inletID, capability: capability, result: .failed(failure))
        }
    }

    var offers: [Offer] { config.company.offers }

    private func checkLimits(_ offer: Offer) throws(SetupError) {
        for capability in offer.capabilities {
            let maximum = limit(capability)
            let used = inlets.filter { $0.owner == offer.owner && $0.capabilities.contains(capability) }.count
            if used >= maximum { throw .limitReached(capability, max: maximum) }
        }
    }

    func add(_ offer: Offer, input: Input) async throws(SetupError) -> Inlet {
        guard let provider = providers[offer.provider] else {
            throw .probeFailed(Hint(text: "hint.provider.unknown", detail: offer.provider))
        }
        try checkLimits(offer)
        var inlet = Inlet(id: offer.provider + "-" + UUID().uuidString, provider: offer.provider,
                          capabilities: offer.capabilities, owner: offer.owner, title: offer.title)
        let grant: Grant
        do {
            grant = try await provider.signIn.signIn(inlet, input: input.values)
        } catch is CancellationError {
            throw .cancelled
        } catch {
            throw .probeFailed(hint(error))
        }
        inlet.state = .signedIn
        inlet.state = .connecting
        let result: ProbeResult
        do {
            result = try await provider.probe.probe(inlet, grant)
        } catch {
            try? await provider.signIn.signOut(inlet)
            throw .probeFailed(hint(error))
        }
        if let rejection = result.rejection {
            try? await provider.signIn.signOut(inlet)
            throw .probeFailed(rejection)
        }
        if inlets.contains(where: { $0.provider == offer.provider && $0.account == result.account }) {
            try? await provider.signIn.signOut(inlet)
            throw .duplicate
        }
        do {
            try checkLimits(offer)
        } catch {
            try? await provider.signIn.signOut(inlet)
            throw error
        }
        var written: [KeySlot] = []
        do {
            for (name, value) in grant.values.sorted(by: { $0.key < $1.key }) {
                let slot = KeySlot(inlet: inlet.id, name: name)
                try config.keychain.put(value, at: slot)
                written.append(slot)
            }
            inlet.account = result.account
            inlet.state = .connected(probed: config.clock())
            try store.save(inlet, slots: grant.values.keys.sorted())
        } catch {
            for slot in written { try? config.keychain.delete(slot) }
            try? await provider.signIn.signOut(inlet)
            if case KeychainError.status(let status) = error { throw .keychain(status) }
            throw .keychain(-1)
        }
        grants[inlet.id] = grant
        inlets.append(inlet)
        emit(.inletChanged(inlet.id))
        for capability in inlet.capabilities {
            config.cadence.plan(inlet.id, capability, cadence(inlet.id, capability))
        }
        return inlet
    }

    func probe(_ inletID: Inlet.ID) async throws(SetupError) -> ProbeResult {
        guard let inlet = inlets.first(where: { $0.id == inletID }), let provider = providers[inlet.provider] else {
            throw .probeFailed(Hint(text: "hint.inlet.unknown", detail: inletID))
        }
        guard let grant = grant(for: inlet) else {
            update(inletID, persist: false) { $0.state = .keychainUnreadable }
            throw .probeFailed(Hint(text: "hint.keychain.unreadable", fixIn: .inlet(inletID)))
        }
        update(inletID, persist: false) { $0.state = .connecting }
        do {
            let result = try await provider.probe.probe(inlet, grant)
            if let rejection = result.rejection {
                update(inletID, persist: true) { $0.state = .failed(rejection) }
                throw SetupError.probeFailed(rejection)
            }
            let now = config.clock()
            update(inletID, persist: true) { $0.state = .connected(probed: now) }
            return result
        } catch let error as SetupError {
            throw error
        } catch {
            let failure = hint(error, fixIn: .inlet(inletID))
            update(inletID, persist: true) { $0.state = .failed(failure) }
            throw .probeFailed(failure)
        }
    }

    func remove(_ inletID: Inlet.ID) async throws {
        guard let inlet = inlets.first(where: { $0.id == inletID }) else { return }
        for capability in inlet.capabilities { config.cadence.plan(inletID, capability, .off) }
        let names = try store.slots(of: inletID)
        for name in names { try config.keychain.delete(KeySlot(inlet: inletID, name: name)) }
        if let provider = providers[inlet.provider] { try? await provider.signIn.signOut(inlet) }
        try store.delete(inletID)
        try store.deleteSettings(withPrefix: "cadence|\(inletID)|")
        try store.deleteSettings(withPrefix: "lock|\(inletID)|")
        cadences = cadences.filter { !$0.key.hasPrefix(inletID + "|") }
        locks = locks.filter { !$0.key.hasPrefix(inletID + "|") }
        for (kind, truth) in truths where truth == inletID {
            truths[kind] = nil
            try store.deleteSettings(withPrefix: "truth|\(kind.rawValue)")
        }
        grants[inletID] = nil
        for kind in delivered.keys { delivered[kind]?[inletID] = nil }
        inlets.removeAll { $0.id == inletID }
        for list in feeds.values { list.forEach { $0.drop(inlet: inletID) } }
        emit(.inletChanged(inletID))
    }

    func cadence(_ inlet: Inlet.ID, _ capability: Capability) -> Cadence {
        cadences[inlet + "|" + capability.rawValue] ?? .manual
    }

    func setCadence(_ inlet: Inlet.ID, _ capability: Capability, _ value: Cadence) {
        let key = inlet + "|" + capability.rawValue
        cadences[key] = value
        persist("cadence|" + key, value)
        if inlets.first(where: { $0.id == inlet })?.state.isConnected == true {
            config.cadence.plan(inlet, capability, value)
        }
    }

    func truth(_ kind: DataKind) -> Inlet.ID? { truths[kind] }

    func setTruth(_ kind: DataKind, _ inlet: Inlet.ID) {
        truths[kind] = inlet
        persist("truth|" + kind.rawValue, inlet)
    }

    func cost(_ inlet: Inlet.ID, _ period: Period) -> Cost { config.cost.sum(inlet, period) }

    func limit(_ capability: Capability) -> Int { limits[capability] ?? Int.max }

    func setLimit(_ capability: Capability, _ value: Int) {
        limits[capability] = value
        persist("limit|" + capability.rawValue, value)
    }

    func may(_ person: Person.ID, _ right: Right) -> Bool {
        let role = roles[person] ?? config.company.defaultRole
        return config.company.rights[role]?.contains(right) ?? false
    }

    func setRole(_ person: Person.ID, _ role: Role) {
        roles[person] = role
        persist("role|" + person, role)
    }

    func lock(_ inlet: Inlet.ID, _ right: Right, _ rule: LockRule) {
        let key = inlet + "|" + right.rawValue
        locks[key] = rule
        persist("lock|" + key, rule)
    }
}
