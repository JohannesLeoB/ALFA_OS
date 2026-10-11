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

    public func origin(window: Size, geometry g: ShellGeometry) -> Point {
        let stripTop = (g.strip - g.blobHeight) / 2
        func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double { min(high, max(low, value)) }
        switch edge {
        case .top:
            return Point(x: clamp(offset, g.margin, window.width - g.margin - g.blobWidth), y: stripTop)
        case .bottom:
            return Point(x: clamp(offset, g.margin, window.width - g.margin - g.blobWidth), y: window.height - g.margin - g.blobHeight)
        case .leading:
            return Point(x: g.margin, y: clamp(offset, stripTop, window.height - g.margin - g.blobHeight))
        case .trailing:
            return Point(x: window.width - g.margin - g.blobWidth, y: clamp(offset, stripTop, window.height - g.margin - g.blobHeight))
        }
    }

    public static func settle(dropAt center: Point, velocity: Point, window: Size, geometry g: ShellGeometry) -> BlobPlacement {
        let cx = center.x + velocity.x * g.blobThrow
        let cy = center.y + velocity.y * g.blobThrow
        let distances: [(Edge, Double)] = [(.top, cy), (.bottom, window.height - cy), (.leading, cx), (.trailing, window.width - cx)]
        let edge = distances.min { $0.1 < $1.1 }?.0 ?? .top
        switch edge {
        case .top, .bottom: return BlobPlacement(edge: edge, offset: cx - g.blobWidth / 2)
        case .leading, .trailing: return BlobPlacement(edge: edge, offset: cy - g.blobHeight / 2)
        }
    }

    public func menuOrigin(window: Size, geometry g: ShellGeometry) -> (origin: Point, opensDownward: Bool) {
        let blob = origin(window: window, geometry: g)
        let downward = blob.y + g.blobHeight / 2 < window.height / 2
        var x = edge == .trailing ? blob.x + g.blobWidth - g.menuWidth : blob.x
        x = min(window.width - g.margin - g.menuWidth, max(g.margin, x))
        let y = downward ? blob.y + g.blobHeight + g.menuGap : blob.y - g.menuGap
        return (Point(x: x, y: y), downward)
    }
}
