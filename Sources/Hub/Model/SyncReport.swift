import Foundation

public struct SyncReport: Equatable, Sendable {
    public enum Result: Equatable, Sendable {
        case finished(items: Int)
        case skipped
        case failed(Hint)
    }

    var inlet: Inlet.ID
    var capability: Capability
    var result: Result

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
