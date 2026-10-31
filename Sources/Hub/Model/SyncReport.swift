import Foundation

public struct SyncReport: Equatable, Sendable {
    public enum Result: Equatable, Sendable {
        case finished(items: Int)
        case skipped
        case failed(Hint)
    }

    public var inlet: Inlet.ID
    public var capability: Capability
    public var result: Result

    init(inlet: Inlet.ID, capability: Capability, result: Result) {
        self.inlet = inlet
        self.capability = capability
        self.result = result
    }
}

public struct SyncJob: Equatable, Sendable {
    var inlet: Inlet.ID
    var capability: Capability
    var startedAt: Date

    init(inlet: Inlet.ID, capability: Capability, startedAt: Date) {
        self.inlet = inlet
        self.capability = capability
        self.startedAt = startedAt
    }
}

public struct RunProgress: Equatable, Sendable {
    public let done: Int
    public let total: Int

    public init?(done: Int, total: Int) {
        guard total > 0 else { return nil }
        self.total = total
        self.done = min(max(done, 0), total)
    }
}

public struct SyncReporter: Sendable {
    private let deliver: @Sendable (RunProgress) -> Void

    public init(_ deliver: @escaping @Sendable (RunProgress) -> Void) {
        self.deliver = deliver
    }

    public func callAsFunction(done: Int, total: Int) {
        guard let progress = RunProgress(done: done, total: total) else { return }
        deliver(progress)
    }
}

public struct SyncOutcome: Sendable {
    var deliveries: [DataKind: [any Item]]

    public init(deliveries: [DataKind: [any Item]] = [:]) {
        self.deliveries = deliveries
    }

    var count: Int { deliveries.values.reduce(0) { $0 + $1.count } }
}

public protocol Item: Identifiable, Sendable where ID == String {
    var inlet: Inlet.ID { get }
}
