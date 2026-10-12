import Foundation

public final class TimerCadence: CadencePort, @unchecked Sendable {
    public typealias Sleep = @Sendable (Duration) async throws -> Void

    private struct Pair: Hashable {
        let inlet: Inlet.ID
        let capability: Capability
    }

    private struct State {
        var runner: SyncRunner?
        var timers: [Pair: Task<Void, Never>] = [:]
        var running: Set<Pair> = []
    }

    private let lock = NSLock()
    private var state = State()
    private let sleep: Sleep
    private let continuation: AsyncStream<SyncReport>.Continuation
    public let reports: AsyncStream<SyncReport>

    public init(sleep: @escaping Sleep = { try await Task.sleep(for: $0) }) {
        self.sleep = sleep
        (reports, continuation) = AsyncStream<SyncReport>.makeStream()
    }

    deinit {
        state.timers.values.forEach { $0.cancel() }
        continuation.finish()
    }

    private func locked<R>(_ body: (inout State) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return body(&state)
    }

    public func attach(_ runner: @escaping SyncRunner) {
        locked { $0.runner = runner }
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
        let previous = locked { state -> Task<Void, Never>? in
            let old = state.timers[pair]
            state.timers[pair] = timer
            return old
        }
        previous?.cancel()
    }

    public func trigger(_ inlet: Inlet.ID, _ capability: Capability) async {
        let pair = Pair(inlet: inlet, capability: capability)
        let runner = locked { state -> SyncRunner? in
            guard let runner = state.runner, !state.running.contains(pair) else { return nil }
            state.running.insert(pair)
            return runner
        }
        guard let runner else { return }
        let report = await runner(inlet, capability)
        _ = locked { $0.running.remove(pair) }
        continuation.yield(report)
    }
}
