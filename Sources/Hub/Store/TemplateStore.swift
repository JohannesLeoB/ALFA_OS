import Foundation
import Storage

public struct TemplateStore: Sendable {
    public struct Template: Identifiable, Equatable, Sendable {
        public let id: String
        public let name: String
        let url: URL
    }

    public static let extensions = ["html", "htm", "mustache"]

    private let directory: URL

    public init(directory: URL = DatabaseStore.directory().appendingPathComponent("templates", isDirectory: true)) {
        self.directory = directory
    }

    public var templates: [Template] {
        let keys: Set<URLResourceKey> = [.creationDateKey]
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys))) ?? []
        return files.filter { Self.extensions.contains($0.pathExtension.lowercased()) }
            .map { url in (url, (try? url.resourceValues(forKeys: keys).creationDate) ?? .distantPast) }
            .sorted { ($0.1, $0.0.lastPathComponent) < ($1.1, $1.0.lastPathComponent) }
            .map { Template(id: $0.0.lastPathComponent, name: $0.0.deletingPathExtension().lastPathComponent, url: $0.0) }
    }

    public var current: Template? { templates.first }

    public func text(_ template: Template) -> String? {
        try? String(contentsOf: template.url, encoding: .utf8)
    }

    @discardableResult
    public func add(from source: URL) throws -> Template {
        let suffix = source.pathExtension.lowercased()
        guard Self.extensions.contains(suffix) else { throw CocoaError(.fileReadUnsupportedScheme) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let base = source.deletingPathExtension().lastPathComponent
        var target = directory.appendingPathComponent(base).appendingPathExtension(suffix)
        var number = 2
        while FileManager.default.fileExists(atPath: target.path) {
            target = directory.appendingPathComponent("\(base) \(number)").appendingPathExtension(suffix)
            number += 1
        }
        try FileManager.default.copyItem(at: source, to: target)
        return Template(id: target.lastPathComponent, name: target.deletingPathExtension().lastPathComponent, url: target)
    }

    public func remove(_ template: Template) throws {
        try FileManager.default.removeItem(at: template.url)
    }
}
