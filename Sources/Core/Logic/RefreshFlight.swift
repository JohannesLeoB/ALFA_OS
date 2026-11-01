import Synchronization

public final class RefreshFlight<Value: Sendable>: Sendable {
    static var remembered: Int { 64 }

    private struct Book {
        var running: [String: Task<Value, any Error>] = [:]
        var latest: [String: Value] = [:]
    }

    private enum Step {
        case ready(Value)
        case waiting(Task<Value, any Error>)
    }

    private let book = Mutex(Book())

    public init() {}

    public func recent(_ key: String) -> Value? {
        book.withLock { $0.latest[key] }
    }

    public func run(_ key: String, reuse: @escaping @Sendable (Value) -> Bool,
                    _ work: @escaping @Sendable () async throws -> Value) async throws -> Value {
        let step = book.withLock { book -> Step in
            if let known = book.latest[key], reuse(known) { return .ready(known) }
            if let running = book.running[key] { return .waiting(running) }
            let started = Task { try await work() }
            book.running[key] = started
            return .waiting(started)
        }
        switch step {
        case .ready(let known):
            return known
        case .waiting(let task):
            do {
                let value = try await task.value
                book.withLock { book in
                    book.latest[key] = value
                    if book.running[key] == task { book.running[key] = nil }
                    if book.latest.count > Self.remembered { book.latest = book.latest.filter { reuse($0.value) } }
                }
                return value
            } catch {
                book.withLock { book in if book.running[key] == task { book.running[key] = nil } }
                throw error
            }
        }
    }
}
