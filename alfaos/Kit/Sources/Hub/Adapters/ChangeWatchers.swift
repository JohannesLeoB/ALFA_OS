import Foundation

final class ChangeWatchers: @unchecked Sendable {
    static let longestPause: Duration = .seconds(300)

    private let firstPause: Duration
    private let lock = NSLock()
    private var tasks: [String: Task<Void, Never>] = [:]

    init(firstPause: Duration) {
        self.firstPause = firstPause
    }

    deinit {
        tasks.values.forEach { $0.cancel() }
    }

    func start(
        _ key: String,
        port: any ChangePort,
        isTransient: @escaping @Sendable (any Error) -> Bool,
        fire: @escaping @Sendable () async -> Void
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
                    if Task.isCancelled || !isTransient(error) { return }
                }
                do { try await Task.sleep(for: wait) } catch { return }
                wait = min(wait * 2, Self.longestPause)
            }
        }
        let previous = lock.withLock { () -> Task<Void, Never>? in
            let old = tasks[key]
            tasks[key] = task
            return old
        }
        previous?.cancel()
    }

    func stop(_ key: String) {
        let old = lock.withLock { tasks.removeValue(forKey: key) }
        old?.cancel()
    }
}
