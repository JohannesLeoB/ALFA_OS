import Foundation

public struct Cost: Equatable, Sendable {
    var calls: Int
    var bytes: Int
    var tokens: Int

    init(calls: Int = 0, bytes: Int = 0, tokens: Int = 0) {
        self.calls = calls
        self.bytes = bytes
        self.tokens = tokens
    }
}

public struct CostItem: Equatable, Sendable {
    var inlet: Inlet.ID
    var capability: Capability
    var cost: Cost
    var at: Date

    init(inlet: Inlet.ID, capability: Capability, cost: Cost, at: Date) {
        self.inlet = inlet
        self.capability = capability
        self.cost = cost
        self.at = at
    }
}

public struct CostMeter: Sendable {
    let inlet: Inlet.ID
    let capability: Capability
    let cost: any CostPort
    let clock: @Sendable () -> Date

    init(inlet: Inlet.ID, capability: Capability, cost: any CostPort, clock: @escaping @Sendable () -> Date) {
        self.inlet = inlet
        self.capability = capability
        self.cost = cost
        self.clock = clock
    }

    public func record(calls: Int = 1, bytes: Int = 0, tokens: Int = 0) {
        cost.book(CostItem(inlet: inlet, capability: capability,
                           cost: Cost(calls: calls, bytes: bytes, tokens: tokens), at: clock()))
    }
}
