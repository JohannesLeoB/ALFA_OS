import CoreGraphics
import Foundation
import ImageIO

/// Still images of code cards, kept in memory and as PNG files in one folder. Files are named by their key,
/// so the folder can be deleted at any time. Without a folder the cache lives in memory only.
/// Encoding and writing happen off the main thread. The folder keeps at most `fileLimit` files; the least recently used go first.
@MainActor
public final class StillCache {
    /// Most PNG files kept in the folder.
    public nonisolated static let fileLimit = 300

    private let folder: URL?
    private let memoryLimit: Int
    private var memory: [String: CGImage] = [:]
    /// Keys in order of use, the oldest first.
    private var recent: [String] = []

    public init(folder: URL?, memoryLimit: Int = 64) {
        self.folder = folder
        self.memoryLimit = max(1, memoryLimit)
    }

    /// The still with this key, from memory or from its file. Nil when there is none.
    public func image(for key: String) -> CGImage? {
        if let image = memory[key] {
            touch(key)
            return image
        }
        guard let url = fileURL(for: key),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        // Reading counts as use, so the file is not the first to go.
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        remember(image, for: key)
        return image
    }

    /// Keeps the still in memory and writes it to its file off the main thread. Returns when the file is written.
    public func store(_ image: CGImage, for key: String) async {
        remember(image, for: key)
        guard let folder, let url = fileURL(for: key) else { return }
        await Task.detached(priority: .utility) {
            StillCache.write(image, to: url, folder: folder)
            StillCache.trim(folder: folder, limit: StillCache.fileLimit)
        }.value
    }

    /// Drops the copies in memory. The files stay.
    public func clearMemory() {
        memory = [:]
        recent = []
    }

    private func fileURL(for key: String) -> URL? {
        folder?.appendingPathComponent(key + ".png")
    }

    private func remember(_ image: CGImage, for key: String) {
        memory[key] = image
        touch(key)
        while recent.count > memoryLimit {
            memory[recent.removeFirst()] = nil
        }
    }

    private func touch(_ key: String) {
        recent.removeAll { $0 == key }
        recent.append(key)
    }

    /// Writes the image as PNG. Runs off the main thread.
    nonisolated static func write(_ image: CGImage, to url: URL, folder: URL) {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? (data as Data).write(to: url, options: .atomic)
    }

    /// Removes the PNG files of the folder that are not among the `limit` most recently changed ones.
    nonisolated static func trim(folder: URL, limit: Int) {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys) else { return }
        let dated = files
            .filter { $0.pathExtension == "png" }
            .map { url in (url, (try? url.resourceValues(forKeys: Set(keys)).contentModificationDate) ?? .distantPast) }
            .sorted { $0.1 > $1.1 }
        for (url, _) in dated.dropFirst(max(0, limit)) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
