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

    @discardableResult
    public func trigger(_ inlet: Inlet.ID, _ capability: Capability) async -> SyncReport {
        let pair = Pair(inlet: inlet, capability: capability)
        let runner = state.withLock { current -> SyncPort? in
            guard let runner = current.runner, !current.running.contains(pair) else { return nil }
            current.running.insert(pair)
            return runner
        }
        guard let runner else { return SyncReport(inlet: inlet, capability: capability, result: .skipped) }
        let report = await runner(inlet, capability)
        _ = state.withLock { $0.running.remove(pair) }
        return report
    }
}

final class FolderChanges: FolderWatchPort {
    static let longestPause: Duration = .seconds(300)

    private let firstPause: Duration
    private let tasks = Mutex<[String: Task<Void, Never>]>([:])

    init(firstPause: Duration) {
        self.firstPause = firstPause
    }

    deinit {
        tasks.withLock { $0.values.forEach { $0.cancel() } }
    }

    func start(
        _ key: String,
        port: any ChangePort,
        isTransient: @escaping @Sendable (any Error) -> Bool,
        fire: @escaping @Sendable () async -> Void,
        unavailable: @escaping @Sendable () -> Void
    ) {
        let firstPause = self.firstPause
        let task = Task {
            var wait = firstPause
            while !Task.isCancelled {
                do {
                    for try await _ in port.changes() {
                        wait = firstPause
                        await fire()
                    }
                } catch {
                    if Task.isCancelled { return }
                    if !isTransient(error) {
                        unavailable()
                        return
                    }
                }
                do { try await Task.sleep(for: wait) } catch { return }
                wait = min(wait * 2, Self.longestPause)
            }
        }
        let previous = tasks.withLock { current -> Task<Void, Never>? in
            let old = current[key]
            current[key] = task
            return old
        }
        previous?.cancel()
    }

    func stop(_ key: String) {
        let old = tasks.withLock { $0.removeValue(forKey: key) }
        old?.cancel()
    }
}
