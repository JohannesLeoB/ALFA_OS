import Foundation

public struct TemplateFile: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    let url: URL
}
