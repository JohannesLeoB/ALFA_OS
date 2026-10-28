import Design

public enum LaneKind: String, Sendable, Codable, CaseIterable {
    case leading
    case center
    case trailing

    public var index: Int {
        switch self {
        case .leading: 0
        case .center: 1
        case .trailing: 2
        }
    }

    public var headLeading: Double { self == .trailing ? Tokens.Size.headPadLeftStack : Tokens.Size.headPadLeftList }

    public var headTrailing: Double { Tokens.Size.headPadRight }

    public var headGap: Double { self == .trailing ? Tokens.Size.headGapStack : Tokens.Size.headGapList }
}

struct AreaRules: Sendable, Equatable {
    let minimum: [Double]
    let maximum: [Double?]
    let yield: [Int]

    init(minimum: [Double], maximum: [Double?] = [nil, nil, nil], yield: [Int] = [0, 1, 2]) {
        self.minimum = minimum
        self.maximum = maximum
        self.yield = yield
    }

    static func area(_ id: String, measure: Measure) -> AreaRules {
        guard id == "mail" else { return AreaRules(minimum: measure.minimum) }
        var minimum = measure.minimum
        minimum[LaneKind.leading.index] = Tokens.Size.mailLaneMinimumLeft
        return AreaRules(minimum: minimum, maximum: [Tokens.Size.mailLaneMaximumLeft, nil, nil])
    }
}

public struct LaneWidths: Sendable, Equatable {
    public let leading: Double
    public let center: Double
    public let trailing: Double

    public var all: [Double] { [leading, center, trailing] }

    public func width(_ lane: LaneKind) -> Double {
        all[lane.index]
    }
}

public struct LaneMode: Sendable, Codable, Equatable {
    var preferred: [Double]
    var folded: [Bool]
    var pinned: Bool
    public var maximized: LaneKind?

    init(rest: Double) {
        preferred = [rest, 0, rest]
        folded = [false, false, false]
        pinned = false
        maximized = nil
    }
}
