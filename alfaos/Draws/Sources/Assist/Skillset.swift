import Foundation

public struct Skillset: Sendable, Equatable {
    public struct Entry: Codable, Sendable, Equatable {
        public var key: String
        public var file: String

        public init(key: String, file: String) {
            self.key = key
            self.file = file
        }
    }

    public struct Manifest: Codable, Sendable, Equatable {
        public var id: String
        public var core: String
        public var addons: [Entry]

        public init(id: String, core: String, addons: [Entry]) {
            self.id = id
            self.core = core
            self.addons = addons
        }
    }

    public var manifest: Manifest
    public var files: [String: String]
    public var keys: [String]

    public init(manifest: Manifest, files: [String: String], keys: [String] = []) {
        self.manifest = manifest
        self.files = files
        self.keys = keys
    }

    public static func load(_ folder: URL, keys: [String] = []) throws -> Skillset {
        let manifest: Manifest
        do {
            manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: folder.appendingPathComponent("manifest.json")))
        } catch {
            throw Fault.malformed("manifest")
        }
        var files: [String: String] = [:]
        for name in [manifest.core] + manifest.addons.map(\.file) {
            guard let text = try? String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8) else {
                throw Fault.malformed(name)
            }
            files[name] = text
        }
        return Skillset(manifest: manifest, files: files, keys: keys)
    }

    public func merging(_ other: Skillset) -> Skillset {
        let id = other.manifest.id
        let tag = { (name: String) in id + "/" + name }
        var merged = files
        for (name, text) in other.files { merged[tag(name)] = text }
        let core = Entry(key: id, file: tag(other.manifest.core))
        let addons = other.manifest.addons.map { Entry(key: id + "." + $0.key, file: tag($0.file)) }
        let next = Manifest(id: manifest.id + "+" + id, core: manifest.core, addons: [core] + manifest.addons + addons)
        return Skillset(manifest: next, files: merged, keys: keys + [id] + other.keys.map { id + "." + $0 })
    }

    public func selecting(_ keys: [String]) -> Skillset {
        var next = self
        next.keys = keys
        return next
    }

    public var prompt: String {
        let chosen = manifest.addons.filter { keys.contains($0.key) }
        let parts = [manifest.core] + chosen.map(\.file)
        return parts.compactMap { files[$0] }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: "\n\n")
    }
}

public struct StyleMaster: Sendable, Equatable, Codable {
    public var name: String
    public var weights: [String: JSON]

    public init(name: String, weights: [String: JSON]) {
        self.name = name
        self.weights = weights
    }

    public static func load(_ url: URL) throws -> StyleMaster {
        do {
            return try JSONDecoder().decode(StyleMaster.self, from: Data(contentsOf: url))
        } catch {
            throw Fault.malformed(url.lastPathComponent)
        }
    }

    public func number(_ key: String) -> Double? { weights[key]?.number }

    public func text(_ key: String) -> String? { weights[key]?.string }

    public func flag(_ key: String) -> Bool? { weights[key]?.bool }

    public func value(_ key: String) -> JSON? { weights[key] }

    public var block: String {
        let lines = weights.keys.sorted().compactMap { key in
            weights[key].map { value in "- \(key): \(value.string ?? value.text)" }
        }
        return (["Style master \(name). Weigh these preferences in every choice; the person's words override them."] + lines)
            .joined(separator: "\n")
    }
}
