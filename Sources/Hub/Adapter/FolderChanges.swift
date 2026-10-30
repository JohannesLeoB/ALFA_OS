import Synchronization

final class FolderChanges: Sendable {
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
