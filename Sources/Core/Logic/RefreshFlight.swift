import Synchronization

public final class RefreshFlight<Value: Sendable>: Sendable {
    static var remembered: Int { 64 }

    private let running = Mutex<[String: Task<Value, any Error>]>([:])
    private let latest = Mutex<[String: Value]>([:])

    public init() {}

    public func recent(_ key: String) -> Value? {
        latest.withLock { $0[key] }
    }

    public func run(_ key: String, _ work: @escaping @Sendable () async throws -> Value) async throws -> Value {
        let task = running.withLock { slots in
            if let slot = slots[key] { return slot }
            let started = Task { try await work() }
            slots[key] = started
            return started
        }
        defer { running.withLock { slots in if slots[key] == task { slots[key] = nil } } }
        let value = try await task.value
        latest.withLock { known in
            if known.count >= Self.remembered { known.removeAll() }
            known[key] = value
        }
        return value
    }
}
