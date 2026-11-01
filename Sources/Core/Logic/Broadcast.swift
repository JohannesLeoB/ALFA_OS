import Foundation

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
