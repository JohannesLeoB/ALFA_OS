/// Runs jobs with at most `limit` of them at once. The others wait and start in the order they came.
@MainActor
public final class JobQueue {
    private let limit: Int
    private var running = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []

    public init(limit: Int) {
        self.limit = max(1, limit)
    }

    /// Waits for a free place, runs the job, and frees the place again.
    public func run<T>(_ job: @MainActor () async throws -> T) async rethrows -> T {
        await acquire()
        defer { release() }
        return try await job()
    }

    private func acquire() async {
        guard running >= limit else {
            running += 1
            return
        }
        // The place passes straight to the next waiter in release(), so running does not change.
        await withCheckedContinuation { waiting.append($0) }
    }

    private func release() {
        guard !waiting.isEmpty else {
            running -= 1
            return
        }
        waiting.removeFirst().resume()
    }
}
