import Foundation

public protocol SettingPort: Sendable {
    func all() throws -> [String: Data]
    func value<V: Decodable>(_ key: String, as type: V.Type) throws -> V?
    func store<V: Encodable>(_ value: V, forKey key: String) throws
    func remove(key: String) throws
    func remove(withPrefix prefix: String) throws
}

public protocol TemplatePort: Sendable {
    var templates: [TemplateFile] { get }
    func text(_ template: TemplateFile) -> String?
    func add(from source: URL) throws -> TemplateFile
    func remove(_ template: TemplateFile) throws
}
