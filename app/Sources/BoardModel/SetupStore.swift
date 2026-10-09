import Foundation

/// Reads and writes the saved setups as one JSON file, `setups.json`. The app gives the file's place.
public struct SetupStore: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// The saved setups. An empty list when the file is missing or cannot be read.
    public func load() -> [Setup] {
        guard let data = try? Data(contentsOf: url),
              let setups = try? JSONDecoder().decode([Setup].self, from: data) else { return [] }
        return setups
    }

    /// Writes the whole list, creating the folder when it is missing.
    public func save(_ setups: [Setup]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(setups).write(to: url, options: .atomic)
    }
}
