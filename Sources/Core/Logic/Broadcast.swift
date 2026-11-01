import Foundation
import Synchronization

@MainActor
public final class Broadcast<Event: Sendable> {
    private var listeners: [UUID: AsyncStream<Event>.Continuation] = [:]

    public init() {}

    public var stream: AsyncStream<Event> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Event>.makeStream()
        listeners[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.listeners[id] = nil }
        }
        return stream
    }

    public func emit(_ event: Event) {
        for continuation in listeners.values { continuation.yield(event) }
    }
}

public final class SingleFlight<Value: Sendable>: Sendable {
    private let running = Mutex<Task<Value, any Error>?>(nil)

    public init() {}

    public func run(_ work: @escaping @Sendable () async throws -> Value) async throws -> Value {
        let task = running.withLock { slot in
            if let slot { return slot }
            let started = Task { try await work() }
            slot = started
            return started
        }
        defer { running.withLock { slot in if slot == task { slot = nil } } }
        return try await task.value
    }
}
