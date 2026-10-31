import Design
import Foundation

struct AreaRules: Sendable, Equatable {
    let minimum: [Double]
    let maximum: [Double?]
    let yield: [Int]

    init(minimum: [Double], maximum: [Double?] = [nil, nil, nil], yield: [Int] = [0, 1, 2]) {
        self.minimum = minimum
        self.maximum = maximum
        self.yield = yield
    }

    init(measure: Measure, limits: AreaLimits) {
        self.init(minimum: LaneKind.allCases.map { limits.minimum[$0] ?? measure.minimum[$0.index] },
                  maximum: LaneKind.allCases.map { limits.maximum[$0] })
    }
}

public struct AreaLimits: Sendable, Equatable {
    let minimum: [LaneKind: Double]
    let maximum: [LaneKind: Double]

    public init(minimum: [LaneKind: Double] = [:], maximum: [LaneKind: Double] = [:]) {
        self.minimum = minimum
        self.maximum = maximum
    }
}

public struct LaneMode: Sendable, Codable, Equatable {
    var preferred: [Double]
    var folded: [Bool]
    var squeezed: [Bool]
    public var maximized: LaneKind?

    init(rest: Double) {
        preferred = [rest, 0, rest]
        folded = [false, false, false]
        squeezed = [false, false, false]
        maximized = nil
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preferred = try container.decode([Double].self, forKey: .preferred)
        folded = try container.decode([Bool].self, forKey: .folded)
        squeezed = try container.decodeIfPresent([Bool].self, forKey: .squeezed) ?? [false, false, false]
        maximized = try container.decodeIfPresent(LaneKind.self, forKey: .maximized)
    }
}

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

public struct LaneWidths: Sendable, Equatable {
    public let leading: Double
    public let center: Double
    public let trailing: Double

    public var all: [Double] { [leading, center, trailing] }

    public func width(_ lane: LaneKind) -> Double {
        all[lane.index]
    }
}

public struct Measure: Sendable, Equatable {
    public let margin: Double
    public let gap: Double
    public let strip: Double
    public let blobTop: Double
    let laneRest: Double
    public let laneFolded: Double
    public let foldAt: Double
    public let minimum: [Double]
    public let blobWidth: Double
    public let blobHeight: Double
    let blobDock: Double
    let menuWidth: Double
    public let windowMin: BlobSize

    public init() {
        margin = Tokens.Size.edge
        gap = Tokens.Size.gutter
        blobTop = Tokens.Size.edge
        strip = Tokens.Size.edge + Tokens.Size.blobHeight + Tokens.Size.gutter
        laneRest = Tokens.Size.laneRestWidth
        laneFolded = Tokens.Size.foldedWidth
        foldAt = Tokens.Size.foldThreshold
        minimum = [Tokens.Size.laneMinimumLeft, Tokens.Size.middleMinimumWidth, Tokens.Size.laneMinimumRight]
        blobWidth = Tokens.Size.blobWidth
        blobHeight = Tokens.Size.blobHeight
        blobDock = Tokens.Size.blobDockDistance
        menuWidth = Tokens.Size.blobPopupFallbackWidth
        windowMin = Self.windowMin(margin: Tokens.Size.edge, gap: Tokens.Size.gutter, minimum: minimum, screen: ShellValues.previewScreen)
    }

    public func windowMin(screen: BlobSize) -> BlobSize {
        Self.windowMin(margin: margin, gap: gap, minimum: minimum, screen: screen)
    }

    public func lefts(_ widths: LaneWidths) -> [Double] {
        [margin, margin + widths.leading + gap, margin + widths.leading + widths.center + 2 * gap]
    }

    public func lane(at x: Double, _ widths: LaneWidths) -> LaneKind {
        let lefts = lefts(widths)
        return LaneKind.allCases.last { x >= lefts[$0.index] } ?? .leading
    }

    public func laneHeight(_ window: BlobSize) -> Double {
        window.height - strip - margin
    }

    private static func windowMin(margin: Double, gap: Double, minimum: [Double], screen: BlobSize) -> BlobSize {
        let width = 2 * margin + 2 * gap + minimum.reduce(0, +)
        guard screen.width > 0, screen.height > 0 else { return BlobSize(width: width, height: width) }
        return BlobSize(width: width, height: (width * screen.height / screen.width).rounded(.up))
    }
}

public enum ShellValues {
    static let previewScreen = BlobSize(width: Tokens.Size.previewWindowWidth, height: Tokens.Size.previewWindowHeight)
    public static let pointerStep = 0.001
    static let stretchPerSpeed = 0.00012
    static let dockHoverGrow = 4.0
    static let stripDoubleClickWindow = 0.6
    public static let commandIconCost = 28.0
    public static let commandSendCost = 92.0
    public static let commandConfirmCost = 290.0
    static let commandSeparatorCost = 9.0
    static let commandSlack = 12.0
}

public struct PointerSample: Equatable, Sendable {
    public let point: BlobPoint
    public let time: Double

    public init(point: BlobPoint, time: Double) {
        self.point = point
        self.time = time
    }
}

public struct BlobStretch: Equatable, Sendable {
    public let angle: Double
    public let amount: Double

    public static let none = BlobStretch(angle: 0, amount: 0)

    init(angle: Double, amount: Double) {
        self.angle = angle
        self.amount = amount
    }

    public init(history: [PointerSample]) {
        let pair = history.suffix(2)
        guard pair.count == 2, let a = pair.first, let b = pair.last else {
            self = .none
            return
        }
        let span = max(ShellValues.pointerStep, b.time - a.time)
        let vx = (b.point.x - a.point.x) / span
        let vy = (b.point.y - a.point.y) / span
        angle = atan2(vy, vx)
        amount = min(Tokens.Size.blobStretchMax, hypot(vx, vy) * ShellValues.stretchPerSpeed)
    }
}
