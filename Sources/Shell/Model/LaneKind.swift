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
