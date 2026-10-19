import Foundation

public struct Point: Sendable, Equatable, Codable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct Size: Sendable, Equatable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public enum Edge: String, Sendable, Codable, CaseIterable {
    case top
    case bottom
    case leading
    case trailing
}

public enum BlobPhase: Sendable, Equatable {
    case rest
    case awake
    case menuOpen
}

public struct BlobPlacement: Sendable, Codable, Equatable {
    public var edge: Edge
    public var offset: Double

    public init(edge: Edge, offset: Double) {
        self.edge = edge
        self.offset = offset
    }

    public static func home(geometry g: ShellGeometry) -> BlobPlacement {
        BlobPlacement(edge: .top, offset: g.margin)
    }

    public var isDocked: Bool { edge == .leading || edge == .trailing }

    public var normalized: BlobPlacement {
        isDocked ? self : BlobPlacement(edge: .top, offset: offset)
    }

    public func origin(window: Size, geometry g: ShellGeometry) -> Point {
        func clamp(_ value: Double) -> Double { min(window.height - g.blobHeight - g.margin, max(g.strip, value)) }
        switch edge {
        case .top:
            return Point(x: g.margin, y: g.blobTop)
        case .bottom:
            return Point(x: g.margin, y: window.height - g.margin - g.blobHeight)
        case .leading:
            return Point(x: 0, y: clamp(offset))
        case .trailing:
            return Point(x: window.width - g.blobDock, y: clamp(offset))
        }
    }

    public static func settle(dropAt center: Point, velocity: Point, window: Size, geometry g: ShellGeometry) -> BlobPlacement {
        let rate = Design.Motion.deceleration
        let projection = rate / (1 - rate) / 1000
        let x = center.x - g.blobWidth / 2 + velocity.x * projection
        let y = center.y - g.blobHeight / 2 + velocity.y * projection
        let near = hypot(x - g.margin, y - g.blobTop) < Design.Size.blobHomeRadius
        if y < g.strip || near { return home(geometry: g) }
        let edge: Edge = x + g.blobWidth / 2 < window.width / 2 ? .leading : .trailing
        return BlobPlacement(edge: edge, offset: min(window.height - g.blobHeight - g.margin, max(g.strip, y)))
    }

    public func opensUpward(window: Size, geometry g: ShellGeometry) -> Bool {
        origin(window: window, geometry: g).y + g.blobHeight / 2 > window.height / 2
    }

    public func menuOrigin(window: Size, geometry g: ShellGeometry) -> (origin: Point, opensDownward: Bool) {
        let blob = origin(window: window, geometry: g)
        let upward = opensUpward(window: window, geometry: g)
        let x = edge == .trailing ? window.width - g.margin - g.menuWidth : g.margin
        return (Point(x: x, y: upward ? blob.y + g.blobHeight : blob.y), !upward)
    }

    public func menuRoom(window: Size, geometry g: ShellGeometry) -> Double {
        let y = origin(window: window, geometry: g).y
        let room = opensUpward(window: window, geometry: g) ? y - g.margin : window.height - g.margin - y - g.blobHeight
        return max(Design.Size.blobMenuMinHeight, room - Design.Size.menuEdge)
    }

    public static func awakeWidth(label: Double) -> Double {
        let need = (Design.Spacing.blobInset + Design.Size.symbolSize + Design.Size.menuRowGap + label + Design.Size.blobLabelPadding).rounded(.up)
        return need <= Design.Size.blobAwakeWidth ? Design.Size.blobAwakeWidth : Design.Size.blobPopupFallbackWidth
    }
}
