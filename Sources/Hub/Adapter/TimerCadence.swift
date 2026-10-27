import Foundation
import Synchronization

public final class TimerCadence: CadencePort {
    public typealias Sleep = @Sendable (Duration) async throws -> Void

    private struct Pair: Hashable {
        let inlet: Inlet.ID
        let capability: Capability
    }

    private struct State {
        var runner: SyncPort?
        var timers: [Pair: Task<Void, Never>] = [:]
        var running: Set<Pair> = []
    }

    private let state = Mutex(State())
    private let sleep: Sleep

    public init(sleep: @escaping Sleep = { try await Task.sleep(for: $0) }) {
        self.sleep = sleep
    }

    deinit {
        state.withLock { $0.timers.values.forEach { $0.cancel() } }
    }

    public func attach(_ runner: @escaping SyncPort) {
        state.withLock { $0.runner = runner }
    }

    public func plan(_ inlet: Inlet.ID, _ capability: Capability, _ cadence: Cadence) {
        let pair = Pair(inlet: inlet, capability: capability)
        var timer: Task<Void, Never>?
        if case .every(let interval) = cadence {
            let sleep = self.sleep
            timer = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await sleep(interval) } catch { return }
                    guard !Task.isCancelled, let self else { return }
                    await self.trigger(pair.inlet, pair.capability)
                }
            }
        }
        let previous = state.withLock { current -> Task<Void, Never>? in
            let old = current.timers[pair]
            current.timers[pair] = timer
            return old
        }
        previous?.cancel()
    }

    public func trigger(_ inlet: Inlet.ID, _ capability: Capability) async {
        let pair = Pair(inlet: inlet, capability: capability)
        let runner = state.withLock { current -> SyncPort? in
            guard let runner = current.runner, !current.running.contains(pair) else { return nil }
            current.running.insert(pair)
            return runner
        }
        guard let runner else { return }
        _ = await runner(inlet, capability)
        _ = state.withLock { $0.running.remove(pair) }
    }
}
