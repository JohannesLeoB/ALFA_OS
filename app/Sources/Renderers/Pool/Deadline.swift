/// The work did not end in time.
public struct DeadlineExceeded: Error, Equatable {
    public init() {}
}

/// Gives the result of the first of the two to end: the work, or the time. A work that does not end keeps running in
/// the background, so the owner of the page must drop the page as well.
@MainActor
public func withDeadline<T: Sendable>(seconds: Double, _ work: @escaping @MainActor () async throws -> T) async throws -> T {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, any Error>) in
        let latch = ResultLatch(continuation)
        Task { @MainActor in
            do {
                latch.finish(.success(try await work()))
            } catch {
                latch.finish(.failure(error))
            }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            latch.finish(.failure(DeadlineExceeded()))
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

    func finish(_ result: Result<T, any Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}
