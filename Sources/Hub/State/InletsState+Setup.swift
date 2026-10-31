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
        var inlet = SetupEngine.newInlet(id: offer.provider + "-" + UUID().uuidString, offer: offer)
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
        if let existing = SetupEngine.existing(offer: offer, account: result.account, in: records) {
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
            for slot in written { try? configuration.keychain.delete(slot) }
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

    private func renew(_ existing: Inlet, with grant: Grant) throws(SetupFailure) -> Inlet {
        do {
            for (name, value) in SetupEngine.sorted(grant) {
                try configuration.keychain.put(value, at: KeySlot(inlet: existing.id, name: name))
            }
            var inlet = existing
            inlet.state = .connected(probed: configuration.clock())
            try inletStore.save(inlet, slots: SetupEngine.sorted(grant).map(\.key))
            grants[inlet.id] = grant
            rest(inlet.id, as: inlet.state, persist: .never)
            for capability in inlet.capabilities { plan(inlet.id, capability) }
            return inlet
        } catch {
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

    func remove(_ inletID: Inlet.ID) async throws {
        guard let inlet = record(inletID) else { return }
        let names = try inletStore.slots(of: inletID)
        var saved: [String: String] = [:]
        for name in names {
            if let value = (try? configuration.keychain.get(KeySlot(inlet: inletID, name: name))) ?? nil { saved[name] = value }
        }
        var attempted: [String] = []
        for name in names {
            attempted.append(name)
            do {
                try configuration.keychain.delete(KeySlot(inlet: inletID, name: name))
            } catch {
                for done in attempted {
                    if let value = saved[done] { try? configuration.keychain.put(value, at: KeySlot(inlet: inletID, name: done)) }
                }
                throw error
            }
        }
        for capability in inlet.capabilities {
            configuration.cadence.plan(inletID, capability, .off)
            watchers.stop(SyncEngine.key(inletID, capability))
        }
        if let provider = router.provider(inlet.provider) { try? await provider.signIn.signOut(inlet) }
        try inletStore.delete(inletID)
        try settingStore.remove(withPrefix: Self.cadencePrefix + inletID + "|")
        cadences = cadences.filter { !$0.key.hasPrefix(inletID + "|") }
        try settingStore.remove(withPrefix: Self.lastSyncPrefix + inletID + "|")
        syncedAt = syncedAt.filter { !$0.key.hasPrefix(inletID + "|") }
        try settingStore.remove(key: SettingsKey.mailboxDisplay(inletID))
        try settingStore.remove(key: SettingsKey.mailboxName(inletID))
        grants[inletID] = nil
        forget(inletID)
        reports[inletID] = nil
        for kind in delivered.keys { delivered[kind]?[inletID] = nil }
        records.removeAll { $0.id == inletID }
        for list in feeds.values { list.forEach { $0.drop(inlet: inletID) } }
        emit(.inletRemoved(inletID))
    }
}
