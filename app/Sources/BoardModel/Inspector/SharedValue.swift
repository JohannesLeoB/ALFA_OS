/// What a field shows for a selection: the value when all items agree, `mixed` when they differ, `none` without items.
public enum SharedValue<Value: Equatable & Sendable>: Equatable, Sendable {
    case none
    case value(Value)
    case mixed

    public init(_ values: [Value]) {
        guard let first = values.first else {
            self = .none
            return
        }
        self = values.allSatisfy { $0 == first } ? .value(first) : .mixed
    }

    /// The shared value, or nil when the items differ or there are none.
    public var value: Value? {
        if case .value(let shared) = self { return shared }
        return nil
    }
}
