import Foundation

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
