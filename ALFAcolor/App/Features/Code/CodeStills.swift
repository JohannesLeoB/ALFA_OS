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
    private var running: [String: Task<CGImage, any Error>] = [:]
    /// Failures other than network failures, by key, for this session.
    private var failed: [String: any Error] = [:]

    init(folder: URL?) {
        cache = StillCache(folder: folder)
    }

    /// The still of the card at `width`, from the cache or taken now. Throws when the card cannot be drawn.
    /// A failure other than a network failure is kept, so the same content does not start a page again.
    func still(for card: CodeCard, width: Double, renderer: any CardRenderer) async throws -> CGImage {
        let key = StillKey.make(card: card, width: width)
        if let image = cache.image(for: key) { return image }
        if let error = failed[key] { throw error }
        if let task = running[key] { return try await task.value }
        let queue = queue
        let task = Task { try await queue.run { try await renderer.snapshot(card, width: width) } }
        running[key] = task
        defer { running[key] = nil }
        do {
            let image = try await task.value
            cache.store(image, for: key)
            return image
        } catch {
            if case CardRendererError.network = error {} else { failed[key] = error }
            throw error
        }
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
