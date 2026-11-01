import Core
import Foundation

extension InletsState: SetupPort {
    var inlets: [Inlet] { records }

    var offers: [Offer] { configuration.company.offers }

    func report(for inlet: Inlet.ID) -> [ReportEntry] { reports[inlet] ?? [] }

    func heldSlots(of inlet: Inlet.ID) -> Set<String> {
        Set((try? inletStore.slots(of: inlet)) ?? [])
    }

    func add(_ offer: Offer, input: Input) async throws(SetupFailure) -> Inlet {
        guard let provider = router.provider(offer.provider) else {
            throw .probeFailed(Hint(text: HintEngine.unknownProviderText, detail: offer.provider))
        }
        var inlet = SetupEngine.inlet(id: offer.provider + "-" + UUID().uuidString, offer: offer)
        let grant: Grant
        let candidate = inlet
        let values = input.values
        do {
            grant = try await Deadline.run(configuration.deadlines.signIn) {
                try await provider.signIn.signIn(candidate, input: values)
            }
        } catch is CancellationError {
            throw .cancelled
        } catch is DeadlineExpired {
            throw .probeFailed(Hint(text: HintEngine.signInTimeoutText))
        } catch {
            throw .probeFailed(HintEngine.hint(provider.classify(error)))
        }
        inlet.state = .connecting
        let probing = inlet
        let result: ProbeResult
        do {
            result = try await Deadline.run(configuration.deadlines.probe) { try await provider.probe.probe(probing, grant) }
        } catch is CancellationError {
            try? await provider.signIn.signOut(inlet)
            throw .cancelled
        } catch is DeadlineExpired {
            try? await provider.signIn.signOut(inlet)
            throw .probeFailed(Hint(text: HintEngine.timeoutText))
        } catch {
            try? await provider.signIn.signOut(inlet)
            throw .probeFailed(HintEngine.hint(provider.classify(error)))
        }
        if let rejection = result.rejection {
            try? await provider.signIn.signOut(inlet)
            throw .probeFailed(rejection)
        }
        if let expected = input.expectedAccount, SetupEngine.differs(expected, from: result.account) {
            try? await provider.signIn.signOut(inlet)
            throw .probeFailed(Hint(text: HintEngine.accountMismatchText, detail: expected))
        }
        if let target = input.renews, let renewed = record(target), renewed.provider == offer.provider {
            return try renew(renewed, with: grant, account: result.account)
        }
        if let existing = SetupEngine.existing(offer: offer, account: result.account, in: records) {
            if existing.provider == offer.provider, !offer.capabilities.isSubset(of: existing.capabilities) {
                var widened = existing
                widened.capabilities.formUnion(offer.capabilities)
                widened.title = offer.title
                return try renew(widened, with: grant)
            }
            guard existing.provider == offer.provider, existing.state.canRenew else {
                try? await provider.signIn.signOut(inlet)
                throw .duplicate
            }
            return try renew(existing, with: grant)
        }
        var written: [KeySlot] = []
        do {
            for (name, value) in SetupEngine.sorted(grant) {
                let slot = KeySlot(inlet: inlet.id, name: name)
                try configuration.keychain.put(value, at: slot)
                written.append(slot)
            }
            inlet.account = result.account
            inlet.state = .connected(probed: configuration.clock())
            try inletStore.save(inlet, slots: SetupEngine.sorted(grant).map(\.key))
        } catch {
            for slot in written { release(slot) }
            try? await provider.signIn.signOut(inlet)
            throw SetupEngine.keychainFailure(error)
        }
        grants[inlet.id] = grant
        records.append(inlet)
        log(inlet.id, .probe, ok: true)
        emit(.inletChanged(inlet.id))
        for capability in inlet.capabilities { plan(inlet.id, capability) }
        return inlet
    }

    private func release(_ slot: KeySlot) {
        do {
            try configuration.keychain.delete(slot)
        } catch {
            Log.failure("KeySlotNotReleased", detail: String(describing: error))
        }
    }

    private func restore(_ value: String, at slot: KeySlot) {
        do {
            try configuration.keychain.put(value, at: slot)
        } catch {
            Log.failure("KeySlotNotRestored", detail: String(describing: error))
        }
    }

    private func renew(_ existing: Inlet, with grant: Grant, account: String? = nil) throws(SetupFailure) -> Inlet {
        let previous = (try? inletStore.slots(of: existing.id)) ?? []
        var saved: [String: String] = [:]
        for name in Set(previous).union(grant.values.keys) {
            if let value = (try? configuration.keychain.get(KeySlot(inlet: existing.id, name: name))) ?? nil { saved[name] = value }
        }
        var written: [String] = []
        do {
            for (name, value) in SetupEngine.sorted(grant) {
                written.append(name)
                try configuration.keychain.put(value, at: KeySlot(inlet: existing.id, name: name))
            }
            var inlet = existing
            if let account { inlet.account = account }
            inlet.state = .connected(probed: configuration.clock())
            try inletStore.save(inlet, slots: SetupEngine.sorted(grant).map(\.key))
            let kept = Set(grant.values.keys)
            for name in previous where !kept.contains(name) {
                release(KeySlot(inlet: existing.id, name: name))
            }
            grants[inlet.id] = grant
            if let index = records.firstIndex(where: { $0.id == inlet.id }) { records[index] = inlet }
            rest(inlet.id, as: inlet.state, persist: .never)
            for capability in inlet.capabilities { plan(inlet.id, capability) }
            return inlet
        } catch {
            for name in written {
                let slot = KeySlot(inlet: existing.id, name: name)
                if let value = saved[name] { restore(value, at: slot) } else { release(slot) }
            }
            throw SetupEngine.keychainFailure(error)
        }
    }

    func probe(_ inletID: Inlet.ID) async throws(SetupFailure) -> ProbeResult {
        guard let inlet = record(inletID), let provider = router.provider(inlet.provider) else {
            throw .probeFailed(Hint(text: HintEngine.unknownInletText, detail: inletID))
        }
        guard let grant = grant(for: inlet) else {
            rest(inletID, as: .keychainUnreadable, persist: .never)
            throw .probeFailed(Hint(text: HintEngine.unreadableText, fixIn: .inlet(inletID)))
        }
        beginProbe(inletID)
        defer { endProbe(inletID) }
        do {
            let limit = configuration.deadlines.probe
            let result = try await Deadline.run(limit) { try await provider.probe.probe(inlet, grant) }
            if let rejection = result.rejection {
                logFailure(inletID, .probe, rejection)
                if rejection.kind != .transient { endProbe(inletID, as: .failed(rejection), persist: .changed) }
                throw SetupFailure.probeFailed(rejection)
            }
            let now = configuration.clock()
            log(inletID, .probe, ok: true)
            endProbe(inletID, as: .connected(probed: now), persist: .always)
            for capability in inlet.capabilities { plan(inletID, capability) }
            return result
        } catch let error as SetupFailure {
            throw error
        } catch is DeadlineExpired {
            let failure = Hint(text: HintEngine.timeoutText, fixIn: .inlet(inletID), kind: .transient)
            logFailure(inletID, .probe, failure)
            throw .probeFailed(failure)
        } catch {
            if error is CancellationError { throw .cancelled }
            let classification = classify(error, inlet: inletID)
            let failure = HintEngine.hint(classification, fixIn: .inlet(inletID))
            logFailure(inletID, .probe, failure)
            if classification.kind != .transient { endProbe(inletID, as: .failed(failure), persist: .changed) }
            throw .probeFailed(failure)
        }
    }

    func revoke(_ inletID: Inlet.ID) async throws {
        guard let inlet = record(inletID), let provider = router.provider(inlet.provider), let grant = grant(for: inlet) else { return }
        try await provider.signIn.revoke(grant)
    }

    func remove(_ inletID: Inlet.ID) async throws {
        guard let inlet = record(inletID) else { return }
        let names = try inletStore.slots(of: inletID)
        var saved: [String: String] = [:]
        for name in names {
            if let value = (try? configuration.keychain.get(KeySlot(inlet: inletID, name: name))) ?? nil {
                saved[name] = value
            } else if let cached = grants[inletID]?.values[name] {
                saved[name] = cached
            }
        }
        func restore(_ done: [String]) {
            for name in done {
                if let value = saved[name] { self.restore(value, at: KeySlot(inlet: inletID, name: name)) }
            }
        }
        var attempted: [String] = []
        for name in names {
            attempted.append(name)
            do {
                try configuration.keychain.delete(KeySlot(inlet: inletID, name: name))
            } catch {
                restore(attempted)
                throw error
            }
        }
        do {
            try inletStore.delete(inletID)
        } catch {
            restore(attempted)
            throw error
        }
        grants[inletID] = nil
        forget(inletID)
        reports[inletID] = nil
        for kind in delivered.keys { delivered[kind]?[inletID] = nil }
        records.removeAll { $0.id == inletID }
        for capability in inlet.capabilities {
            configuration.cadence.plan(inletID, capability, .off)
            watchers.stop(SyncEngine.key(inletID, capability))
        }
        if let provider = router.provider(inlet.provider) { try? await provider.signIn.signOut(inlet) }
        for prefix in [Self.cadencePrefix, Self.lastSyncPrefix] {
            do {
                try settingStore.remove(withPrefix: prefix + inletID + "|")
            } catch {
                Log.failure("RemoveSettingsLeft", detail: String(describing: error))
            }
        }
        cadences = cadences.filter { !$0.key.hasPrefix(inletID + "|") }
        syncedAt = syncedAt.filter { !$0.key.hasPrefix(inletID + "|") }
        for key in [SettingsKey.mailboxDisplay(inletID), SettingsKey.mailboxName(inletID)] {
            do {
                try settingStore.remove(key: key)
            } catch {
                Log.failure("RemoveSettingsLeft", detail: String(describing: error))
            }
        }
        for list in feeds.values { list.forEach { $0.drop(inlet: inletID) } }
        emit(.inletRemoved(inletID))
    }
}
