/// The work did not end in time.
public struct DeadlineExceeded: Error, Equatable {
    public init() {}
}

/// Gives the result of the first of the two to end: the work, or the time. When the time ends first, the work is
/// cancelled. A cancelled work that cannot stop by itself, such as a script that loops, must be released by its owner.
@MainActor
public func withDeadline<T: Sendable>(seconds: Double, _ work: @escaping @MainActor () async throws -> T) async throws -> T {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, any Error>) in
        let latch = ResultLatch(continuation)
        let worker = Task { @MainActor in
            do {
                latch.finish(.success(try await work()))
            } catch {
                latch.finish(.failure(error))
            }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            if latch.finish(.failure(DeadlineExceeded())) {
                worker.cancel()
            }
        }
    }
}

/// Resumes its continuation once. Later results are dropped.
@MainActor
private final class ResultLatch<T: Sendable> {
    private var continuation: CheckedContinuation<T, any Error>?

    init(_ continuation: CheckedContinuation<T, any Error>) {
        self.continuation = continuation
    }

    /// Returns true when this result was the one that resumed the continuation.
    @discardableResult
    func finish(_ result: Result<T, any Error>) -> Bool {
        guard let continuation else { return false }
        self.continuation = nil
        continuation.resume(with: result)
        return true
    }
}
