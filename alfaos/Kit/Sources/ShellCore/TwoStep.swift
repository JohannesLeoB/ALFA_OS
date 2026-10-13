public struct TwoStep<ID: Hashable & Sendable>: Equatable, Sendable {
    public private(set) var armed: ID?

    public init() {}

    public mutating func press(_ id: ID) -> Bool {
        if armed == id {
            armed = nil
            return true
        }
        armed = id
        return false
    }

    public mutating func cancel() {
        armed = nil
    }
}
