import Foundation

struct DeadlineExpired: Error, Equatable {}

private final class Race<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, any Error>?
    private var outcome: Result<T, any Error>?
    private var finished = false
    private var tasks: [Task<Void, Never>] = []

    func install(_ continuation: CheckedContinuation<T, any Error>) {
        let ready: Result<T, any Error>? = lock.withLock {
            if let outcome { return outcome }
            self.continuation = continuation
            return nil
        }
        if let ready { continuation.resume(with: ready) }
    }

    func attach(_ tasks: [Task<Void, Never>]) {
        let stale: Bool = lock.withLock {
            self.tasks = tasks
            return finished
        }
        if stale { tasks.forEach { $0.cancel() } }
    }

    func finish(_ result: Result<T, any Error>) {
        let (waiting, running): (CheckedContinuation<T, any Error>?, [Task<Void, Never>]) = lock.withLock {
            guard !finished else { return (nil, []) }
            finished = true
            outcome = result
            let waiting = continuation
            continuation = nil
            return (waiting, tasks)
        }
        running.forEach { $0.cancel() }
        waiting?.resume(with: result)
    }
}

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
