import Foundation
import ImageIO
import CoreGraphics
import Document

/// Makes downsized copies of the images of a document and keeps them in memory.
/// One copy is made per image and step. A request for a copy that is already there, or being made, makes no new one.
/// A larger copy that is in memory answers a request for a smaller one.
public actor ThumbnailCache {
    private struct Copy {
        let thumbnail: Thumbnail
        let cost: Int
        let assetID: String
        let step: Int
        var lastUsed: Int
    }

    private var copies: [String: Copy] = [:]
    private var running: [String: Task<Thumbnail, any Error>] = [:]
    /// Steps of the copies held in memory, per image.
    private var made: [String: Set<Int>] = [:]
    private let byteLimit: Int
    private var bytesHeld = 0
    private var clock = 0

    /// How many images were decoded. For tests.
    public private(set) var decodeCount = 0

    /// `byteLimit` caps the memory of the copies. The least recently used copy is dropped first.
    public init(byteLimit: Int = 256 * 1024 * 1024) {
        self.byteLimit = byteLimit
    }

    /// A copy of the image with a longer side of `edge` pixels, or the original size when that is smaller.
    public func thumbnail(assetID: String, entry: AssetStore.Entry, edge: Int) async throws -> Thumbnail {
        let wanted = ThumbnailEdge.step(for: Double(edge))
        if let held = held(assetID, atLeast: wanted) { return held }
        let key = Self.key(assetID, wanted)
        if let task = running[key] { return try await task.value }
        let task = Task.detached(priority: .userInitiated) { try Self.decode(assetID: assetID, entry: entry, edge: wanted) }
        running[key] = task
        decodeCount += 1
        defer { running[key] = nil }
        let result = try await task.value
        store(result, assetID: assetID, step: wanted)
        return result
    }

    /// The copy in memory with the smallest step that is at least `step`.
    private func held(_ assetID: String, atLeast step: Int) -> Thumbnail? {
        for candidate in (made[assetID] ?? []).sorted() where candidate >= step {
            let key = Self.key(assetID, candidate)
            guard var copy = copies[key] else { continue }
            clock += 1
            copy.lastUsed = clock
            copies[key] = copy
            return copy.thumbnail
        }
        return nil
    }

    private func store(_ thumbnail: Thumbnail, assetID: String, step: Int) {
        let cost = thumbnail.image.bytesPerRow * thumbnail.image.height
        clock += 1
        remove(Self.key(assetID, step))
        copies[Self.key(assetID, step)] = Copy(thumbnail: thumbnail, cost: cost, assetID: assetID, step: step, lastUsed: clock)
        bytesHeld += cost
        made[assetID, default: []].insert(step)
        while bytesHeld > byteLimit, copies.count > 1,
              let oldest = copies.min(by: { $0.value.lastUsed < $1.value.lastUsed }) {
            remove(oldest.key)
        }
    }

    private func remove(_ key: String) {
        guard let copy = copies.removeValue(forKey: key) else { return }
        bytesHeld -= copy.cost
        made[copy.assetID]?.remove(copy.step)
        if made[copy.assetID]?.isEmpty == true { made[copy.assetID] = nil }
    }

    /// Forgets the copies of one image, for example after it was replaced.
    public func forget(assetID: String) {
        for step in made[assetID] ?? [] { remove(Self.key(assetID, step)) }
        made[assetID] = nil
    }

    private static func key(_ assetID: String, _ step: Int) -> String { "\(assetID)#\(step)" }

    private static func decode(assetID: String, entry: AssetStore.Entry, edge: Int) throws -> Thumbnail {
        let data: Data
        do { data = try entry.data() } catch {
            throw ThumbnailError.unreadable(assetID: assetID, reason: error.localizedDescription)
        }
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options), CGImageSourceGetCount(source) > 0,
              let original = originalSize(of: source) else { throw ThumbnailError.notAnImage(assetID: assetID) }
        let request: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: min(edge, original.longerSide)
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, request as CFDictionary) else {
            throw ThumbnailError.notAnImage(assetID: assetID)
        }
        return Thumbnail(image: image, original: original, edge: edge)
    }

    /// The pixel size from the file's properties, with the orientation applied. Reads no pixels.
    private static func originalSize(of source: CGImageSource) -> PixelSize? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int, width > 0, height > 0 else { return nil }
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        return (5...8).contains(orientation) ? PixelSize(width: height, height: width) : PixelSize(width: width, height: height)
    }
}
