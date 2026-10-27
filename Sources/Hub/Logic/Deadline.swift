import Foundation
import Synchronization

enum Deadline {
    static func run<T: Sendable>(_ limit: Duration, _ work: @escaping @Sendable () async throws -> T) async throws -> T {
        let race = Race<T>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, any Error>) in
                race.install(continuation)
                let worker = Task {
                    do { race.finish(.success(try await work())) } catch { race.finish(.failure(error)) }
                }
                let timer = Task {
                    try? await Task.sleep(for: limit)
                    race.finish(.failure(DeadlineExpired()))
                }
                race.attach([worker, timer])
            }
        } onCancel: {
            race.finish(.failure(CancellationError()))
        }
    }
}

struct DeadlineExpired: Error, Equatable {}

private final class Race<T: Sendable>: Sendable {
    private struct State {
        var continuation: CheckedContinuation<T, any Error>?
        var outcome: Result<T, any Error>?
        var finished = false
        var tasks: [Task<Void, Never>] = []
    }

    private let state = Mutex(State())

    func install(_ continuation: CheckedContinuation<T, any Error>) {
        let ready: Result<T, any Error>? = state.withLock { current in
            if let outcome = current.outcome { return outcome }
            current.continuation = continuation
            return nil
        }
        if let ready { continuation.resume(with: ready) }
    }

    func attach(_ tasks: [Task<Void, Never>]) {
        let stale: Bool = state.withLock { current in
            current.tasks = tasks
            return current.finished
        }
        if stale { tasks.forEach { $0.cancel() } }
    }

    func finish(_ result: Result<T, any Error>) {
        let (waiting, running): (CheckedContinuation<T, any Error>?, [Task<Void, Never>]) = state.withLock { current in
            guard !current.finished else { return (nil, []) }
            current.finished = true
            current.outcome = result
            let waiting = current.continuation
            current.continuation = nil
            return (waiting, current.tasks)
        }
        running.forEach { $0.cancel() }
        waiting?.resume(with: result)
    }
}
