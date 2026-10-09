import Foundation

/// The direction of a guide. A horizontal guide is a line at a fixed y; a vertical guide at a fixed x.
public enum GuideAxis: String, Codable, Sendable, CaseIterable {
    case horizontal, vertical
}

/// A guide of a frame. Its position is in points from the top left corner of the frame: y for a horizontal
/// guide, x for a vertical one. It lives in the frame, so it moves and scales with it.
public struct Guide: Codable, Hashable, Sendable {
    public var axis: GuideAxis
    public var position: Double

    public init(axis: GuideAxis, position: Double) {
        self.axis = axis
        self.position = position
    }
}
