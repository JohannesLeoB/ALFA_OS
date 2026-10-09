import CoreGraphics
import Foundation
import Renderers

/// The still images of code cards. A still is taken once for each content and width, then read from the cache.
/// At most `concurrentLimit` stills are taken at once; the others wait in line.
@MainActor
final class CodeStills {
    static let shared = CodeStills(folder: defaultFolder)

    static let concurrentLimit = 2

    private let cache: StillCache
    private let queue = JobQueue(limit: CodeStills.concurrentLimit)
    /// Stills being taken, by key, so that a second request waits for the first.
    private var running: [String: Task<CGImage?, Never>] = [:]

    init(folder: URL?) {
        cache = StillCache(folder: folder)
    }

    /// The still of the card at `width`, from the cache or taken now. Nil when the card cannot be drawn.
    func still(for card: CodeCard, width: Double, renderer: any CardRenderer) async -> CGImage? {
        let key = StillKey.make(card: card, width: width)
        if let image = cache.image(for: key) { return image }
        if let task = running[key] { return await task.value }
        let queue = queue
        let task = Task { await queue.run { await renderer.snapshot(card, width: width) } }
        running[key] = task
        let image = await task.value
        running[key] = nil
        if let image { cache.store(image, for: key) }
        return image
    }

    /// Drops the stills in memory when the system is short of memory. The files stay.
    func clearMemory() {
        cache.clearMemory()
    }

    /// The player folder in the caches of the app. The system may empty it at any time.
    static var defaultFolder: URL? {
        guard let caches = try? FileManager.default.url(
            for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else { return nil }
        let bundle = Bundle.main.bundleIdentifier ?? "ALFAcolor"
        return caches
            .appendingPathComponent(bundle, isDirectory: true)
            .appendingPathComponent("player", isDirectory: true)
    }
}
