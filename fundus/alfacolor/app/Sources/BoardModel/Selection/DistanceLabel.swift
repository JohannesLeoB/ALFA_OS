import Foundation

/// What the label of a measured gap says. A gap is shown with the name of the spacing token when it sits on a token,
/// and with the nearest token when it does not.
public struct DistanceLabel: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// No spacing token is known: the number alone.
        case plain
        /// The gap equals the value of a token: "16 · space.s4".
        case onToken
        /// The gap lies beside a token: "15, nearest space.s4".
        case nearToken
    }

    public var value: Double
    /// The name of the nearest spacing token, nil when there is none.
    public var token: String?
    public var kind: Kind

    public init(value: Double, token: String?, kind: Kind) {
        self.value = value; self.token = token; self.kind = kind
    }

    /// Two gaps are on the same token when they differ by less than this, in board points.
    public static let tolerance = 0.005

    public init(_ distance: SnapDistance) {
        value = distance.measure.value
        token = distance.nearest?.name
        if let deviation = distance.deviation {
            kind = abs(deviation) < Self.tolerance ? .onToken : .nearToken
        } else {
            kind = .plain
        }
    }
}

/// How the snapping of a drag or resize behaves. The view sets it from the settings of the window.
public struct SnapSettings: Equatable, Sendable {
    /// Snapping at all. A drag can still suspend it with the Command key.
    public var isOn = true
    /// How near a target must be to catch, in screen points.
    public var tolerance = 6.0
    /// The step of the grid in board points. 0 turns the grid off.
    public var gridStep = 0.0
    /// Gaps snap to the spacing tokens. Off by default.
    public var snapsToSpacing = false

    public init(isOn: Bool = true, tolerance: Double = 6, gridStep: Double = 0, snapsToSpacing: Bool = false) {
        self.isOn = isOn; self.tolerance = tolerance; self.gridStep = gridStep; self.snapsToSpacing = snapsToSpacing
    }
}

/// The arrow keys.
public enum Arrow: Sendable {
    case left, right, up, down

    /// The step in board points for one press. Shift makes it larger.
    public static func distance(large: Bool) -> Double { large ? 10 : 1 }

    var direction: (x: Double, y: Double) {
        switch self {
        case .left: (-1, 0)
        case .right: (1, 0)
        case .up: (0, -1)
        case .down: (0, 1)
        }
    }
}
