import Design
import Foundation

public struct BlobPoint: Sendable, Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct BlobSize: Sendable, Equatable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public enum BlobEdge: String, Sendable, Codable {
    case top
    case leading
    case trailing
}

public struct BlobPlacement: Sendable, Codable, Equatable {
    public var edge: BlobEdge
    var offset: Double

    init(edge: BlobEdge, offset: Double) {
        self.edge = edge
        self.offset = offset
    }

    static func home(measure m: Measure) -> BlobPlacement {
        BlobPlacement(edge: .top, offset: m.margin)
    }

    var isDocked: Bool { edge == .leading || edge == .trailing }

    var normalized: BlobPlacement {
        isDocked ? self : BlobPlacement(edge: .top, offset: offset)
    }

    func origin(window: BlobSize, measure m: Measure) -> BlobPoint {
        func clamp(_ value: Double) -> Double { min(window.height - m.blobHeight - m.margin, max(m.strip, value)) }
        switch edge {
        case .top:
            return BlobPoint(x: m.margin, y: m.blobTop)
        case .leading:
            return BlobPoint(x: 0, y: clamp(offset))
        case .trailing:
            return BlobPoint(x: window.width - m.blobDock, y: clamp(offset))
        }
    }

    static func settle(dropAt center: BlobPoint, velocity: BlobPoint, window: BlobSize, measure m: Measure) -> BlobPlacement {
        let rate = Tokens.Motion.deceleration
        let projection = rate / (1 - rate) / 1000
        let x = center.x - m.blobWidth / 2 + velocity.x * projection
        let y = center.y - m.blobHeight / 2 + velocity.y * projection
        let near = hypot(x - m.margin, y - m.blobTop) < Tokens.Size.blobHomeRadius
        if y < m.strip || near { return home(measure: m) }
        let edge: BlobEdge = x + m.blobWidth / 2 < window.width / 2 ? .leading : .trailing
        return BlobPlacement(edge: edge, offset: min(window.height - m.blobHeight - m.margin, max(m.strip, y)))
    }

    func opensUpward(window: BlobSize, measure m: Measure) -> Bool {
        origin(window: window, measure: m).y + m.blobHeight / 2 > window.height / 2
    }

    public func menuRoom(window: BlobSize, measure m: Measure) -> Double {
        let y = origin(window: window, measure: m).y
        let room = opensUpward(window: window, measure: m) ? y - m.margin : window.height - m.margin - y - m.blobHeight
        return max(Tokens.Size.blobMenuMinHeight, room - Tokens.Size.menuEdge)
    }

    static func awakeWidth(label: Double) -> Double {
        let need = (Tokens.Spacing.blobInset + Tokens.Size.symbolSize + Tokens.Size.menuRowGap + label + Tokens.Size.blobLabelPadding).rounded(.up)
        return need <= Tokens.Size.blobAwakeWidth ? Tokens.Size.blobAwakeWidth : Tokens.Size.blobPopupFallbackWidth
    }
}
