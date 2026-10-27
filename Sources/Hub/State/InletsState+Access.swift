import Foundation

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
            update(inletID, persist: false) { $0.state = .keychainUnreadable }
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
        let previous = inlet.state
        update(inletID, persist: false) { $0.state = .working }
        defer {
            running.remove(key)
            queue.removeAll { $0 == job }
        }
        do {
            let outcome = try await spec.run(provider, inlet, grant, meter(inletID, capability), renewal(inletID))
            let now = configuration.clock()
            if record(inletID) != nil {
                for (kind, items) in outcome.deliveries {
                    delivered[kind, default: [:]][inletID] = (items, now)
                    for feed in feeds[kind] ?? [] { feed.apply(inlet: inletID, records: items, at: now) }
                    emit(.newItems(kind))
                }
                update(inletID, persist: false) { $0.state = previous }
            }
            log(inletID, .sync, capability: capability, ok: true)
            syncedAt[key] = now
            persist(Self.lastSyncPrefix + key, now)
            emit(.syncFinished(capability, inletID))
            return SyncReport(inlet: inletID, capability: capability, result: .finished(items: outcome.count))
        } catch {
            if error is CancellationError {
                update(inletID, persist: false) { if $0.state == .working { $0.state = previous } }
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
                update(inletID, persist: false) { if $0.state == .working { $0.state = previous } }
            case .fail:
                update(inletID, persist: true) { $0.state = .failed(failure) }
            }
            emit(.syncFailed(capability, inletID, failure))
            return SyncReport(inlet: inletID, capability: capability, result: .failed(failure))
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
            update(inletID, persist: true) { $0.state = .failed(failure) }
        }
    }

    private func expire(_ inletID: Inlet.ID, _ error: any Error) {
        guard record(inletID) != nil else { return }
        let failure = HintEngine.hint(Classification(kind: .signIn, original: classify(error, inlet: inletID).original),
                                      fixIn: .inlet(inletID))
        logFailure(inletID, .renewal, failure)
        update(inletID, persist: true) { $0.state = .failed(failure) }
    }
}
