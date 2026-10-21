import Foundation

public struct PromptPreset: Sendable, Equatable, Identifiable, Decodable {
    public var id: String
    public var title: String
    public var prompt: String
}

public enum PromptPresets {
    struct File: Decodable {
        var presets: [PromptPreset]
    }

    public static func load(_ url: URL) -> [PromptPreset] {
        guard let data = try? Data(contentsOf: url), let file = try? JSONDecoder().decode(File.self, from: data) else { return [] }
        var seen = Set<String>()
        return file.presets.filter { item in
            !item.id.isEmpty && !item.title.isEmpty && !item.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && seen.insert(item.id).inserted
        }
    }
}
