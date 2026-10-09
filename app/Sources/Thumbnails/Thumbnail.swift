import Foundation
import CoreGraphics

/// A size in whole pixels.
public struct PixelSize: Equatable, Sendable {
    public var width: Int
    public var height: Int
    public init(width: Int, height: Int) { self.width = width; self.height = height }
    public var longerSide: Int { max(width, height) }
}

/// A downsized copy of an image. It holds the whole image, with the orientation of the file applied.
public struct Thumbnail: @unchecked Sendable {
    public let image: CGImage
    /// The size of the original image, with the orientation applied.
    public let original: PixelSize
    /// The longer side that was asked for. The copy is never larger than the original.
    public let edge: Int

    public var size: PixelSize { PixelSize(width: image.width, height: image.height) }
}

public enum ThumbnailError: Error, Equatable, Sendable {
    /// The bytes of the file could not be read.
    case unreadable(assetID: String, reason: String)
    /// The bytes are not an image that the system can decode.
    case notAnImage(assetID: String)
}

/// The sizes of the copies. A request rounds up to a step, so that a small change of zoom reuses the copy.
public enum ThumbnailEdge {
    public static let steps = [64, 128, 256, 512, 1024, 2048, 4096]

    /// The smallest step that is at least `needed`. The largest step for anything larger, the smallest for anything unusable.
    public static func step(for needed: Double) -> Int {
        guard needed.isFinite, needed > 0 else { return steps[0] }
        return steps.first { Double($0) >= needed } ?? steps[steps.count - 1]
    }
}
